# CopyNote 下一步演进 & UI/动画优化计划

**生成时间**：2026-08-24  
**代码基础**：CopyNote v1.0.0（main 分支最新提交 d4d4b2c）

---

## 一、仓库研究结论

### 当前功能基线（全部完成）
- 便签 CRUD：标题/内容/标签 + JSON 持久化
- 搜索：多关键词 AND，跨标题/内容/标签
- 标签系统：标签 CRUD、按标签筛选、按使用频率排序
- 排序：6 种方式 + 偏好持久化
- 导入导出：批量/单条 JSON
- 单击复制：成功动画反馈 ✅
- 窗口：主窗口置顶、主窗口关闭 → 迷你悬浮条
- 迷你悬浮条：休息态半隐藏、悬停窥视（peek）、左右边缘吸附、拖动吸附
- 全局快捷键：⌥⌘N 切换主窗口/悬浮条（Carbon RegisterEventHotKey）
- 菜单栏：自定义 StatusBar 图标 + 导入导出/展开/退出菜单项
- 紧凑模式：折叠模式单行紧凑显示，悬停显示编辑删除按钮
- 自定义 Dock & StatusBar 图标（纯代码绘制）
- 菜单栏工具栏：纯图标按钮（新建/导入导出/排序/紧凑/置顶/悬浮）

### 当前代码结构
```
Sources/CopyNote/
├── App/CopyNoteApp.swift         MenuBarExtra
├── App/AppDelegate.swift          热键注册 / 屏幕变化 / Dock 图标
├── Models/Note.swift              数据模型（含 tags）
├── Store/NoteStore.swift          CRUD + 搜索 + 标签 + 排序 + 持久化
├── Services/                      6 个服务（Clipboard / EdgeSnap / HotKey / ImportExport / AppIcon）
├── Views/                         5 个视图
│   ├── MainNoteListView.swift     主窗口（Section header 搜索+标签栏）
│   ├── NoteRowView.swift          便签行（full/compact 双模式）
│   ├── NoteEditorView.swift       编辑器（含 FlowLayout 标签）
│   ├── MiniBarView.swift          迷你悬浮条内容
│   └── SearchBar.swift            搜索框
└── Window/
    ├── WindowCoordinator.swift    窗口协调（主/迷你/吸附/peek）
    └── MiniPanelDelegate.swift    迷你面板事件
```

### 技术栈约束
- SwiftUI + AppKit（macOS 14+）
- Swift Package Manager（无 .xcodeproj）
- JSON 文件持久化（无 CoreData/SQLite）
- Carbon 全局热键（无需辅助功能权限）

---

## 二、下一步功能演进建议（按优先级）

### P0 · 高频核心（强烈推荐）

#### F1 便签 Markdown / 富文本渲染
- **现状**：便签内容是纯文本 TextEditor，无格式
- **建议**：在 NoteEditorView 和展开态 NoteRowView 中支持 AttributedString 或简易 Markdown（标题/列表/代码/链接）
- **实现**：
  - 内容字段保持 String（避免破坏现有 JSON）
  - 新增 `MarkdownRenderer` 服务：用 `AttributedString(markdown:)`（macOS 14 原生支持）
  - 编辑态保留 TextEditor（纯文本编辑），列表展示态用渲染后的 AttributedString
- **修改文件**：新增 `Services/MarkdownRenderer.swift`、修改 `NoteEditorView`（底部预览切换）、修改 `NoteRowView`（fullBody 内容用渲染视图）
- **风险**：macOS 14 的 AttributedString Markdown 支持有限，需降级处理语法不支持的部分

#### F2 便签颜色 / 背景色（便签纸视觉）
- **现状**：所有便签外观一致
- **建议**：给每条便签配一个「颜色主题」，在列表和编辑器中应用不同的背景色块，类似物理便签本
- **实现**：
  - `Note` 新增 `colorHex: String`（Codable，6 种预设色 + 自定）
  - `NoteStore` 保持兼容（迁移时为空 → 默认色）
  - `NoteRowView` 行尾或行首加小色条，fullBody 背景淡色
  - `NoteEditorView` 顶栏加色卡选择器（环形色板）
- **修改文件**：`Models/Note.swift`、`Store/NoteStore.swift`（迁移兼容）、`NoteRowView`、`NoteEditorView`
- **风险**：低；字段新增有默认值即可，JSON 向后兼容

#### F3 便签置顶 / 星标 / 「锁定不被删除」
- **现状**：只有全局窗口置顶，便签本身无优先级
- **建议**：
  - 「星标」`Note.isPinned: Bool`：星标便签始终排在列表顶部（排序器前置）
  - 「锁定」`Note.isLocked: Bool`：锁定便签删除前需要确认（二次对话框）
- **实现**：
  - `Note` 新增 `isPinned` / `isLocked` 两字段
  - `NoteStore.sortInPlace()`：先按 isPinned 分两组，组内按 sortOrder
  - `NoteRowView` 加 ⭐ 图标（单击切换 pinned）、🔒 图标；删除时 isLocked → `NSAlert` 确认
- **修改文件**：`Note.swift`、`NoteStore.swift`（sortInPlace 调整）、`NoteRowView`
- **风险**：低

### P1 · 体验增强

#### F4 最近复制历史 / 复制队列
- **现状**：复制一次即覆盖剪贴板
- **建议**：每次复制便签都推入一个 10 条内存历史，顶部工具栏显示「复制历史」弹出菜单，可一键再次复制历史项
- **修改文件**：新增 `ClipboardHistoryStore`（@Observable，10 条循环队列）、修改 `ClipboardService`（复制同时推入历史）、`MainNoteListView` 工具栏加「历史」按钮 Popover

#### F5 便签快捷键重命名 / 删除
- **现状**：只能用鼠标操作
- **建议**：
  - 列表选中便签（`List(selection:)`）→ ⌘E 编辑、⌫ 删除（确认）、⌘D 复制（duplicate）一条新便签、⌘↵ 复制该便签内容
- **修改文件**：`MainNoteListView`（List selection + .onDelete + keyboardShortcut）

#### F6 便签自动按标签归档到分组（分组折叠）
- **现状**：扁平列表 + 标签筛选条
- **建议**：可选的「分组视图」开关，按 `allTags` 把便签分到各组，每组是 DisclosureGroup（可折叠），无标签的归入「未分类」
- **修改文件**：`MainNoteListView`（新增 grouped 开关 + ForEach(allTags) DisclosureGroup 结构）

### P2 · 锦上添花

#### F7 便签内容语音朗读（利用 SpeechSynthesis）
#### F8 数据自动备份（每日复制 notes.json → notes.backup-YYYYMMDD.json）
#### F9 iCloud / CloudKit 多设备同步
#### F10 多语言（i18n，至少 English + 简体中文）

---

## 三、UI 优化建议

### U1 · 主窗口视觉升级（整体调性）
- **背景**：当前 `MainNoteListView` 是纯 SwiftUI 默认灰色背景。改为 `background(.ultraThinMaterial)` 或浅色视觉背景，贴合 macOS 现代审美
- **标题栏**：隐藏主窗口默认标题栏内容（`NSWindow.titlebarAppearsTransparent = true` + `styleMask.insert(.fullSizeContentView)`），让工具栏与内容区视觉融合，去掉「CopyNote」灰色标题条

### U2 · 便签行卡片化（fullBody）
- **现状**：fullBody 是扁平 VStack，左右两侧按钮竖排
- **优化**：把每行套进 `RoundedRectangle(cornerRadius: 10)` 卡片容器，带 0.3 线宽边框 + 极浅背景色（或便签颜色 F2 的背景色）；hovered 时卡片背景稍微加深 0.05 opacity；左右间距拉开
- **按钮横排**：编辑/删除/复制图标改为右下角一行横排（类似 iOS 列表 trailing actions），hovered 时从右侧淡入

### U3 · 标签胶囊视觉统一
- **现状**：NoteEditorView、NoteRowView、标签筛选条三处胶囊样式略不一致
- **优化**：抽一个共用 ViewModifier `TagCapsuleStyle(emphasis: .selected|.normal|.secondary)`，三处全用它

### U4 · MiniBarView 重做
- **现状**：VStack 图标 + 数字 + 标题，宽 56px 高 220px，略显空荡
- **优化**：
  - 改为紧凑纵向条，顶部自定义图标，中部显示便签数量胶囊，底部显示最近 2 条便签的「首字母色块」（每个 16×16，纵向堆叠）
  - 增加「拖拽手势条」视觉（顶部 3px 宽灰色横线），强化可拖动手感
  - 窥视（peek）状态宽度从 56 增加到 90-100，展开显示最近便签标题（1 行）

### U5 · 编辑器（NoteEditorView）质感
- **现状**：默认边框 + 灰色背景
- **优化**：
  - 标题输入框改为无边框、大号字体、placeholder 「便签标题…」
  - 内容编辑器背景加非常淡的便签纸张色渐变（与 F2 颜色联动）
  - 底部标签输入区加「常用标签快速点击」横条（从 store.allTags 取前 6 个）
  - 标题栏右侧显示「字数/字符数」

### U6 · 空状态（emptyState）插画
- **现状**：简单文字提示
- **优化**：用 SF Symbol 组合画「便签本 + 加号」占位图，点击即新建便签

---

## 四、动画效果建议

### A1 · 主窗口与悬浮条切换动画（最高优先级）
- **现状**：`hideToMini` → miniPanel 直接 orderFront，无过渡；`expand` → 直接显示主窗口
- **优化**：
  - `hideToMini()`：先在主窗口当前位置做 shrink 动画（scale 0.3 + 向吸附边缘方向 translate + fade out），同时 miniPanel 从同一起点 scale+fade+translate 到吸附位置。用 `NSAnimationContext` 做双窗口同步动画（duration 0.35，`CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)`）
  - `expand()`：反向动画，miniPanel 放大 + translate + fade 到主窗口原位置
- **风险**：需要先把「mini 目标位置」在动画启动前就计算好（提前调用 snapMiniToEdge(animate: false) 决定）

### A2 · 便签列表增删移动动画
- **现状**：增删是 List 自带的默认插入/删除动画
- **优化**：
  - 新建便签：从顶部带 scale+opacity 插入动画（`withAnimation(.spring(response: 0.35, dampingFraction: 0.8))`）
  - 删除便签：先行高 collapse + opacity 到 0 再移除
  - 排序切换：`withAnimation(.easeInOut(duration: 0.3))` 包裹 `setSortOrder`，让便签行在新旧顺序之间平滑移动
  - 标签筛选：同样包裹在 withAnimation

### A3 · 复制成功动画升级（单击便签）
- **现状**：`scaleEffect 1.15` + 图标变绿
- **优化**：
  - 加一个 `sensoryFeedback(.success)` 触感（SF Symbol 提供，macOS 上转成系统提示音/触控板反馈）
  - 从复制图标位置射出 2-3 个小粒子（SF Symbol `paperclip` / `checkmark`），用 `matchedGeometryEffect` 或自定义 `Canvas` 做 easeOut + opacity 淡出
  - 或者最简单：整行卡片 flash 一下绿色描边（0.5s pulse）

### A4 · hover 微交互
- **便签行卡片**：hovered 时 `scale 1.008` + `shadow(color: .black.opacity(0.08), radius: 4, y: 1)`（轻微浮起），0.2 easeInOut
- **工具栏按钮**：hovered 时背景 `.tint.opacity(0.08)` + 轻微 scale 1.05
- **标签胶囊**：hovered 时 capsule 填充加深（opacity +0.08）+ scale 1.05

### A5 · 迷你悬浮条吸附弹跳
- **现状**：吸附是线性滑动（0.2s easeOut）
- **优化**：拖动松手吸附时，动画最后 15% 加一个 small bounce：`spring(response: 0.3, dampingFraction: 0.85)` 替代当前线性，松手时同时闪一下极小 shadow flash

### A6 · 折叠/展开模式切换过渡
- **现状**：isCompact 切换直接硬切
- **优化**：`withAnimation(.easeInOut(duration: 0.25))` 包裹切换，每一行在 full ↔ compact 之间 transition `.opacity.combined(with: .move(edge: .top))` 或自定义 `AnyTransition.asymmetric(...)`

---

## 五、推荐执行批次（组合打包避免反复）

建议按下面组合分批次实现：

| 批次 | 内容组合 | 原因 |
|------|---------|------|
| **第 1 批** | U1（窗口视觉）+ U2（便签行卡片化）+ A2（列表动画）+ A4（hover 微交互） | 视觉收益最大，改动集中在 View 层，一次整体做完观感提升明显 |
| **第 2 批** | F2（便签颜色）+ U3/U5（标签统一 + 编辑器质感）+ A3（复制动画） | 互相联动（颜色影响卡片背景色），中等复杂度 |
| **第 3 批** | F1（Markdown）+ F3（星标/锁定）+ F5（键盘快捷键） | 功能强相关（都在列表/编辑器层），核心功能 |
| **第 4 批** | A1（窗口切换动画）+ U4（MiniBar 重做）+ A5（吸附弹跳） | 需修改 WindowCoordinator 和 MiniPanelDelegate，底层逻辑集中，适合单独处理 |
| **第 5 批** | F4（复制历史）+ F6（分组视图）+ A6（折叠过渡） | 锦上添花，不影响核心体验 |

---

## 六、风险与依赖

| 项 | 风险 | 规避 |
|---|---|---|
| A1 双窗口过渡动画 | WindowCoordinator 动画状态机变复杂；与 peek/snap 可能冲突 | 先做「关主窗口」和「开主窗口」各独立一条动画路径，用 `isAnimatingMini` gating 确保无重入；动画前先把 lastSnap 和目标 frame 锁定 |
| F1 Markdown 渲染 | macOS 14 AttributedString(markdown:) 不支持表格等语法 | 用 try? 降级，失败时 fallback 到原始纯文本；不引入第三方 Markdown 库（避免体积和依赖） |
| F2 颜色字段新增 | JSON 格式升级，老用户 notes.json 可能无 colorHex | `Note.colorHex` 提供默认值 `""`（表示「默认色」）；JSONDecoder 用 `decodeIfPresent` 保持兼容 |
| U2 卡片化性能 | List 大量便签时阴影/圆角可能性能下降 | 限制 List 阴影半径 ≤ 4；对 >100 行时可改用 `.drawingGroup()` 或移除阴影 |
| 全局热键冲突 | ⌥⌘N 可能被其他应用占用 | HotKeyManager.register 返回 false 时弹出通知（NSUserNotification/UNUserNotification）提示用户；可选设置面板可自定义热键 |

---

## 七、待确认的决策点（在执行前建议先拍板）

1. **是否坚持只使用 Swift 原生组件，不引入第三方库**（当前项目 0 依赖，非常清爽；引入 Markdown 库或 Icon 库都会破坏这一点。建议保持 0 依赖。）
2. **批次执行顺序**：是否按上面推荐的第 1→2→3→4→5 顺序？还是想先做某一两个点（比如先做动画 A1 + 窗口切换）？
3. **F1 Markdown**：只支持「标题/粗体/斜体/列表/代码行/链接」6 种语法够用吗？是否需要表格？
4. **F2 颜色**：仅 6 种预设色，还是允许自定义任意颜色？
