# CopyNote macOS 应用开发计划

## 一、Summary 概述

开发一款 macOS 原生便签管理应用 **CopyNote**，核心能力：
- 便签增删改查（标题 + 内容），关键字搜索
- 点击便签自动复制内容到剪切板
- 主窗口支持「置顶」开关（置于所有窗口之上）
- 主窗口可「隐藏」，切换为屏幕边缘的**迷你悬浮条**（常驻置顶、非激活面板），拖动时自动**吸附**到最近屏幕边缘
- 菜单栏图标（MenuBarExtra）提供显示/隐藏/退出入口

技术栈：**SwiftUI + AppKit 桥接**，SwiftPM 打包，目标 macOS 14.0+，JSON 文件本地持久化。功能简单，不引入数据库/第三方依赖。

## 二、Current State Analysis 当前状态分析

- 工作目录 `/Users/vividz/MyDocument/AI-Work/CodeSpace/CopyNote` 为空，全新项目，无既有代码与约束。
- 用户技术背景偏 Web 开发，但本任务明确要求 macOS 原生窗口行为（置顶/悬浮面板/边缘吸附），已与用户确认采用 **SwiftUI + AppKit** 方案，悬浮形态为 **迷你悬浮条 + 边缘吸附**。
- 将复用 `build-macos-apps` 插件能力：`swiftpm-macos`（包结构）、`build-run-debug`（`script/build_and_run.sh` + `.codex/environments/environment.toml` 一键构建运行）、`appkit-interop`（NSWindow/NSPanel/NSPasteboard 桥接）、`window-management`（窗口层级与材质）。

## 三、Proposed Changes 实施变更

工程结构（SwiftPM，无 .xcodeproj）：

```
CopyNote/
├── Package.swift
├── Sources/CopyNote/
│   ├── App/
│   │   ├── CopyNoteApp.swift          # @main App + AppDelegate 适配器
│   │   └── AppDelegate.swift          # 激活策略、启动协调
│   ├── Models/
│   │   └── Note.swift                 # Codable 便签模型
│   ├── Store/
│   │   └── NoteStore.swift            # @Observable 存储：CRUD + 搜索 + JSON 持久化
│   ├── Services/
│   │   ├── ClipboardService.swift     # NSPasteboard 复制
│   │   └── EdgeSnapService.swift      # 边缘吸附几何计算
│   ├── Window/
│   │   ├── WindowCoordinator.swift    # 拥有主窗口与迷你面板，置顶/隐藏/展开
│   │   └── MiniPanelDelegate.swift    # windowDidMove 触发吸附
│   └── Views/
│       ├── MainNoteListView.swift     # 主窗口：搜索栏 + 列表 + 编辑器
│       ├── NoteRowView.swift          # 单行便签（点击复制）
│       ├── NoteEditorView.swift       # 新建/编辑（标题 + 内容）
│       ├── SearchBar.swift            # 关键字过滤
│       └── MiniBarView.swift          # 悬浮迷你条视图
├── script/
│   └── build_and_run.sh               # 杀进程→swift build→装配 .app→open -n
└── .codex/environments/
    └── environment.toml               # Run 按钮绑定
```

### 3.1 `Package.swift`
**What**：SwiftPM 包定义，executable target `CopyNote`，平台 macOS 14+。
**Why**：SwiftPM 比 .xcodeproj 更易从零引导，`build-run-debug` 技能推荐此路径。
**How**：
```swift
// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "CopyNote",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "CopyNote", path: "Sources/CopyNote")]
)
```

### 3.2 `Models/Note.swift`
**What**：便签数据模型。
**Why**：CRUD 的数据基础，Codable 便于 JSON 持久化。
**How**：
```swift
struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var createdAt: Date = .now
    var updatedAt: Date = .now
}
```

### 3.3 `Store/NoteStore.swift`
**What**：`@Observable` 单例式存储，持有 `[Note]`，提供 `add/update/delete/search`，变更后写盘。
**Why**：SwiftUI 数据源；内存过滤即可满足搜索，避免数据库复杂度。
**How**：
- 持久化路径 `~/Library/Application Support/CopyNote/notes.json`，启动时加载（目录不存在则创建）。
- `search(_ keyword: String) -> [Note]`：按空格拆分多关键词，AND 匹配 title 与 content，`localizedCaseInsensitiveContains`、`localizedStandardCompare` 容忍音调。
- 每次增删改后 `save()` 同步写盘（数据量小，无需异步队列）。

### 3.4 `Services/ClipboardService.swift`
**What**：复制文本到系统剪切板。
**Why**：核心交互「点击便签复制内容」。
**How**：
```swift
@MainActor
enum ClipboardService {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
```

### 3.5 `Services/EdgeSnapService.swift`
**What**：给定窗口 frame 与屏幕 visibleFrame，返回吸附后的 frame（停靠几何）。
**Why**：迷你悬浮条要求贴边吸附。参考 `clawd-on-desk/src/mini.js`+`display-edge.js` 的吸附语义（左/右水平边缘、容差、canonical snap 防 DPI 漂移）。
**How**：
- `snapThreshold: CGFloat = 30`（拖动结束时窗口中心距左/右边缘 ≤30pt 触发吸附，取较近一侧）。
- **仅吸附左/右水平边缘**（`miniEdge: Edge = .left/.right`），不做上/下——便签条为竖向窄条，左右贴边更自然。
- `restVisibleFraction: CGFloat = 0.28`（休息态：仅 28% 宽度露出屏内，其余藏于边缘外）。
- `peekOffset: CGFloat = 24`（悬停时再额外滑出 24pt，参考 clawd `PEEK_OFFSET=25`）。
- 返回 `SnapResult { edge, restFrame, peekFrame, y(clamped) }`；y 用 `max(visibleY, min(y, visibleY+visibleH-height))` 夹取。
- 存储 `lastSnap: SnapResult?`，避免多次拖动/DPI 漂移；显示器分辨率变化时（`NSApplication.didChangeScreenParametersNotification`）按 lastSnap 重新夹取并复位。

### 3.6 `Window/WindowCoordinator.swift`（核心原生行为）
**What**：`@Observable` 窗口协调器，拥有主窗口（NSWindow）与迷你面板（NSPanel）。
**Why**：置顶、隐藏为悬浮条、边缘吸附、悬停窥视均需 AppKit NSWindow/NSPanel 能力，SwiftUI scene 不直接暴露层级控制。
**How**：
- `mainWindow: NSWindow`，`contentRect` 约 `360x520`，`styleMask = [.titled, .closable, .miniaturizable, .resizable]`，`contentViewController = NSHostingController(rootView: MainNoteListView().environmentObject(store))`。
- `miniPanel: NSPanel`，`styleMask = [.borderless, .nonactivatingPanel]`，`level = .floating`，`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`，`isMovableByWindowBackground = true`，`hidesOnDeactivate = false`，`hasShadow = true`，`backgroundColor = .clear`；尺寸宽 `~56`、高 `~220`（竖向窄条），托管 `NSHostingController(rootView: MiniBarView(...))`。`delegate = MiniPanelDelegate(coordinator:)`。
- **休息态半隐藏**：进入迷你模式时按 `EdgeSnapService.snap(...)` 将面板定位至左/右边缘，仅 `restVisibleFraction=0.28` 宽度露于屏内（参考 clawd `calcMiniX` 的 `offsetRatio`）。
- **悬停窥视（peek-on-hover）**：`MiniPanelDelegate` 安装 `NSTrackingArea`，鼠标进入 → `animatePanelToX(peekFrame, 200ms, easeOutQuad)`；鼠标离开 → `animatePanelToX(restFrame, 200ms, easeOutQuad)`。参考 clawd `miniPeekIn/Out`（`PEEK_OFFSET`、`eased = t*(2-t)`）。
- **点击展开**：迷你条 `MiniBarView` `.onTapGesture` → `coordinator.expand()`。
- 状态：`isPinned: Bool`（主窗口置顶），`isMini: Bool`（迷你模式），`currentEdge: Edge`，`isPeeking: Bool`。
- 方法：
  - `togglePin()`：`mainWindow.level = isPinned ? .floating : .normal`。
  - `hideToMini()`：`mainWindow.orderOut(nil)` → 计算 snap → 设面板为 `restFrame` → `miniPanel.orderFrontRegardless()`，`isMini = true`。
  - `peekIn()/peekOut()`：悬停回调用，沿 X 轴滑出/收回（动画器见下）。
  - `expand()`：`miniPanel.orderOut(nil)` → `mainWindow.orderFront(nil)` + `NSApp.activate(ignoringOtherApps: true)`，`isMini = false`。
  - `animatePanelToX(target, duration, easing)`：`NSAnimationContext.runAnimationGroup` 改 `panel.animator().setFrame(_:,display:)`；easing 用 `CAMediaTimingFunction(controlPoints:0.25,0.46,0.45,0.94)`（≈ easeOutQuad）。
- 关闭主窗口（点红点）不退出 app：AppDelegate `applicationShouldTerminateAfterLastWindowClosed -> false`；改为触发 `hideToMini()`（保留常驻悬浮条）。

### 3.7 `Window/MiniPanelDelegate.swift`
**What**：NSWindowDelegate + NSTrackingArea 宿主，处理拖动吸附与悬停窥视。
**Why**：拖动结束触发吸附；鼠标进入/离开触发 peek 滑出/收回（参考 clawd 的 hover 行为）。
**How**：
- `windowDidMove`：取 `window.screen.visibleFrame`，调用 `EdgeSnapService.snap(...)`，更新 `coordinator.lastSnap` 与 `currentEdge`，`window.setFrame(restFrame, display:true, animate:true)` 平滑吸附到休息态（半隐藏）。
- `windowWillMove`：可选抑制吸附抖动（拖动中不吸附）。
- 在迷你面板的 contentView 安装 `NSTrackingArea`（`options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]`）：
  - `mouseEntered` → `coordinator.peekIn()`（滑出 peekFrame）。
  - `mouseExited` → `coordinator.peekOut()`（收回 restFrame）。
- 点击事件交给 SwiftUI `MiniBarView` 的 `.onTapGesture`，不在此处理，避免与 peek 冲突。

### 3.8 `Views/MainNoteListView.swift`
**What**：主窗口根视图，顶部 `SearchBar`，中部 `List` 便签行，底部/工具栏「新建」按钮 + 「置顶」开关 + 「隐藏为悬浮条」按钮。
**How**：`@EnvironmentObject store`，`@State searchText`；列表项 `NoteRowView(note:)`；点 + 调 `store.add(Note(title:"", content:""))` 进入编辑。

### 3.9 `Views/NoteRowView.swift`
**What**：单行便签，显示标题与内容预览；单击复制内容；提供编辑/删除入口。
**How**：`.onTapGesture { ClipboardService.copy(note.content); 触发"已复制"反馈 }`；右键菜单 编辑/删除。

### 3.10 `Views/NoteEditorView.swift`
**What**：标题 `TextField` + 内容 `TextEditor`，实时回写 store。
**How**：双向绑定 `note.title`/`note.content`，变更时 `store.update(note)`（更新 `updatedAt`）。

### 3.11 `Views/SearchBar.swift`
**What**：搜索输入框。
**How**：`TextField` 绑定 `searchText`，列表用 `store.search(searchText)`。

### 3.12 `Views/MiniBarView.swift`
**What**：迷你悬浮条视图（竖向窄条），休息态仅露一窄条，peek 态滑出显示内容；点击展开主窗口。
**Why**：参考 clawd mini 的「休息半藏 + 悬停窥视 + 点击唤起」交互。
**How**：
- 主体 ` VStack`：竖排 app 图标（SF Symbol `note.text`）+ 便签数量徽标；peek 时额外显示最近一条标题（最多 2 行，截断）。
- 休息态由 WindowCoordinator 控制面板 frame（仅 28% 露出），视图自身不需要处理隐藏；peek 时面板滑出，视图内容自然露出。
- `.onTapGesture { coordinator.expand() }` 唤起主窗口；`.contentShape(Rectangle())` 保证窄条全区域可点。
- 背景 `.ultraThinMaterial` 圆角，配合 `backgroundColor=.clear` 的面板呈现毛玻璃窄条。

### 3.13 `App/CopyNoteApp.swift` + `App/AppDelegate.swift`
**What**：`@main` 入口与 AppDelegate。
**How**：
```swift
@main
struct CopyNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { SettingsView() }   // 预留（可空）
        MenuBarExtra("CopyNote", systemImage: "note.text") {
            Button("显示主窗口") { appDelegate.coordinator.expand() }
            Button("隐藏为悬浮条") { appDelegate.coordinator.hideToMini() }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
    }
}
```
- AppDelegate 持有 `coordinator: WindowCoordinator` 与 `store: NoteStore`；`applicationDidFinishLaunching` 中 `NSApp.setActivationPolicy(.regular)`、`NSApp.activate(ignoringOtherApps: true)`，构建并显示主窗口。
- ⚠️ SwiftUI `MenuBarExtra` 与 AppDelegate 手动创建窗口并存时，需确认主窗口在启动时前台显示（必要时由 AppDelegate 显式 `orderFront`）。若 `MenuBarExtra` 导致 app 默认 `.accessory` 行为，AppDelegate 已用 `.regular` 修正。

### 3.14 `script/build_and_run.sh`
**What**：一键 kill → build → 装配 .app → `open -n`。
**Why**：`build-run-debug` 技能规定的一键入口，SwiftPM GUI 需装配 .app bundle 才有 Dock 激活与 bundle 元数据。
**How**：采用技能 `run-button-bootstrap.md` 中「SwiftPM AppKit/SwiftUI GUI app」模板；`APP_NAME=CopyNote`，`BUNDLE_ID=com.vividz.CopyNote`，`MIN_SYSTEM_VERSION=14.0`；`swift build` 后复制二进制到 `dist/CopyNote.app/Contents/MacOS/`，生成最小 `Info.plist`（`CFBundleExecutable/Identifier/Name`、`LSMinimumSystemVersion`、`NSPrincipalClass=NSApplication`），`/usr/bin/open -n` 启动；支持 `--debug/--logs/--telemetry/--verify`。

### 3.15 `.codex/environments/environment.toml`
**What**：Run 按钮绑定到 `./script/build_and_run.sh`（按技能契约）。

## 四、Assumptions & Decisions 假设与决策

1. **持久化用 JSON 文件**而非 SwiftData：功能简单、便签量小，避免模型容器与迁移复杂度。路径 `~/Library/Application Support/CopyNote/notes.json`。
2. **主窗口置顶为开关**（req #2 「可置顶」）：`NSWindow.level = .floating/.normal` 切换，非永久置顶。
3. **隐藏 = 切换迷你悬浮条**（req #3）：主窗口关闭/隐藏时显示迷你 NSPanel；迷你条点击展开回主窗口。点主窗口红点不退出 app，而是进入迷你模式。
4. **边缘吸附仅作用于迷你悬浮条**：主窗口的「置顶」与迷你条的「贴边」是两个独立行为，匹配所选交互「迷你悬浮条 + 边缘吸附」。
4b. **借鉴 clawd-on-desk 的迷你交互**（开源参考，技术栈不同仅取行为）：
   - 休息态半隐藏（仅 ~28% 露出屏内）、悬停窥视 peek（滑出 ~24pt，200ms easeOutQuad）、点击唤起；映射到原生 `NSPanel` frame X 动画 + `NSTrackingArea` + `NSAnimationContext`。
   - 吸附仅左/右水平边缘（取较近一侧，容差 30pt），不做上/下。
   - 存储 canonical snap 防 DPI 漂移，显示器变化时重夹取。
   - **不采用** clawd 的多显示器接缝裁剪（`containedBoundary`/clip）、抛物线跳跃弧（`JUMP_PEAK_HEIGHT`）、crabwalk、12 态动画——对便签条属过度设计，列为未来增强。
5. **非激活面板**：迷你条用 `NSPanel` + `.nonactivatingPanel`，点击不抢焦点，点击展开时再激活主窗口。
6. **菜单栏常驻**：`MenuBarExtra` 提供显示/隐藏/退出，保证 app 在迷你模式也能被唤起与退出。
7. **搜索语义**：多关键词空格分隔、AND、跨标题+内容、大小写/音调不敏感。
8. **暂不做 app 图标资源**：v1 用系统 `note.text` SF Symbol 作为菜单栏图标；.app bundle 不含图标资源（后续可加 Assets.xcassets）。
9. **目标 macOS 14.0+**：使用 `@Observable`（14+）。如需 macOS 15 新窗口 API 再按需加可用性守卫。
10. **不创建 README/文档文件**，除非用户要求。

## 五、Verification 验证步骤

1. `./script/build_and_run.sh` 构建并启动 app，确认 Dock 图标出现、主窗口前台显示。
2. 增删改查：新建便签→输入标题/内容→关闭重开 app 验证持久化；编辑更新；删除。
3. 搜索：输入单/多关键词，确认结果匹配标题或内容。
4. 点击复制：点便签行，在其它 app 粘贴验证内容一致；确认「已复制」反馈。
5. 置顶：开启置顶后，打开其它窗口，确认 CopyNote 主窗口浮于其上；关闭后恢复正常层级。
6. 隐藏为悬浮条：点隐藏→主窗口消失→迷你条出现于左/右屏幕边缘并半隐藏（仅窄条露出）；拖动迷你条靠近左/右边缘（≤30pt）确认自动吸附至休息态。
6b. 悬停窥视：鼠标移近迷你条→平滑滑出（~24pt，200ms）显示便签数量/最近标题；鼠标移开→收回半隐藏；点击→展开主窗口。
7. 展开回主窗口：点迷你条→主窗口恢复前置；切空间（Mission Control）确认迷你条随所有 Space 显示（`.canJoinAllSpaces`）。
8. 菜单栏：菜单栏图标可显示主窗口/隐藏为悬浮条/退出。
9. （可选）`./script/build_and_run.sh --verify` 确认进程存在。
