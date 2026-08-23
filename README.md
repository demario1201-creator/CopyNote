<div align="center">

<img src="docs/copynote-icon.png" width="160" height="160" alt="CopyNote" />

# CopyNote

**轻量级 macOS 便签管理工具 · 快速复制，即取即用**

原生 SwiftUI + AppKit 构建，常驻菜单栏，单击即复制

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue?logo=apple&logoColor=white)](https://github.com/demario1201-creator/CopyNote)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-blue)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/github/license/demario1201-creator/CopyNote?color=green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/demario1201-creator/CopyNote?color=red)](https://github.com/demario1201-creator/CopyNote/releases)

[功能特性](#-功能特性) · [安装](#-安装) · [使用指南](#-使用指南) · [技术架构](#-技术架构) · [开发](#-开发)

</div>

---

## ✨ 功能特性

### 便签管理

| 功能 | 说明 |
| --- | --- |
| 📝 **便签 CRUD** | 创建、编辑、删除便签，支持标题 + 内容 + 标签 |
| 🔍 **智能搜索** | 多关键词搜索（空格分隔，AND 逻辑），跨标题、内容、标签匹配 |
| 🏷️ **标签系统** | 为便签添加标签，按标签快速筛选，标签按使用频率排序 |
| ↕️ **多种排序** | 6 种排序方式：最近更新 / 最早更新 / 最近创建 / 最早创建 / 标题 A→Z / Z→A |
| 📦 **导入导出** | 单条或批量便签 JSON 导入导出，UUID 冲突自动跳过 |
| 📋 **一键复制** | 单击便签即复制内容到剪切板，带复制成功动画反馈 |

### 窗口与交互

| 功能 | 说明 |
| --- | --- |
| 📌 **窗口置顶** | 一键置顶于所有窗口之上，随时查阅 |
| 🫧 **悬浮条模式** | 隐藏为屏幕边缘的迷你悬浮条，鼠标悬停窥视内容 |
| 🧲 **边缘吸附** | 拖动悬浮条靠近屏幕边缘自动吸附，支持左右两侧 |
| ⌨️ **全局快捷键** | `⌥ ⌘ N` 在任何应用中快速切换主窗口与悬浮条 |
| 📐 **折叠模式** | 紧凑单行显示便签标题，鼠标悬停显示操作按钮 |
| 🔔 **菜单栏入口** | 自定义 StatusBar 图标，快捷访问主窗口、导入导出 |

## 📦 安装

### 方式一：下载 Release（推荐）

1. 前往 [Releases 页面](https://github.com/demario1201-creator/CopyNote/releases) 下载最新版 `CopyNote.zip`
2. 解压后将 `CopyNote.app` 拖入「应用程序」文件夹
3. 首次运行如被 Gatekeeper 拦截：
   - 打开「系统设置 → 隐私与安全性」
   - 点击「仍要打开」

### 方式二：源码编译

```bash
git clone https://github.com/demario1201-creator/CopyNote.git
cd CopyNote
swift build --disable-sandbox
bash script/build_and_run.sh run
```

> **系统要求**：macOS 14.0+ (Sonoma) · Apple Silicon (arm64)

## 📖 使用指南

### 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌥ ⌘ N` | 全局切换主窗口 / 悬浮条 |

### 便签操作

| 操作 | 方式 |
| --- | --- |
| **新建便签** | 工具栏点击 ➕ 图标 |
| **复制内容** | 单击便签行（复制成功显示 ✅） |
| **编辑便签** | 悬停便签 → 点击 ✏️ 图标，或右键「编辑」 |
| **删除便签** | 悬停便签 → 点击 🗑️ 图标，或右键「删除」 |
| **搜索便签** | 顶部搜索框输入关键词（空格分隔多词） |
| **添加标签** | 编辑器中输入标签名 → 回车，或右键「添加标签」 |
| **筛选标签** | 点击搜索栏下方的标签胶囊 |
| **切换排序** | 工具栏点击 ↕️ 图标（单击循环 / 长按选择） |
| **折叠/展开** | 工具栏点击 ▭ 图标切换紧凑显示 |
| **导出便签** | 工具栏「导入导出」→ 导出全部 / 右键导出单条 |
| **导入便签** | 工具栏「导入导出」→ 选择 JSON 文件 |

### 窗口操作

| 操作 | 方式 |
| --- | --- |
| **置顶窗口** | 工具栏点击 📌 图标 |
| **隐藏为悬浮条** | 工具栏点击 ◫ 图标 |
| **展开主窗口** | 单击悬浮条，或菜单栏「显示主窗口」 |
| **窥视悬浮条** | 鼠标悬停在悬浮条上 |
| **拖动悬浮条** | 拖动至屏幕边缘自动吸附 |

## 🏗️ 技术架构

```
CopyNote/
├── Sources/CopyNote/
│   ├── App/                    # 应用入口与生命周期
│   │   ├── CopyNoteApp.swift   # @main 入口，MenuBarExtra
│   │   └── AppDelegate.swift   # 窗口协调、热键注册、屏幕变化
│   ├── Models/
│   │   └── Note.swift           # 便签数据模型（Identifiable, Codable）
│   ├── Store/
│   │   └── NoteStore.swift      # 状态管理：CRUD + 搜索 + 标签 + 排序 + 持久化
│   ├── Services/
│   │   ├── ClipboardService.swift    # 剪切板复制
│   │   ├── EdgeSnapService.swift     # 边缘吸附几何计算
│   │   ├── HotKeyManager.swift       # 全局热键（Carbon RegisterEventHotKey）
│   │   ├── ImportExportService.swift  # JSON 导入导出（NSSavePanel/NSOpenPanel）
│   │   └── AppIconFactory.swift      # 纯代码绘制 Dock & StatusBar 图标
│   ├── Views/
│   │   ├── MainNoteListView.swift    # 主窗口：工具栏 + 搜索 + 标签 + 列表
│   │   ├── NoteRowView.swift         # 便签行（展开/折叠双模式）
│   │   ├── NoteEditorView.swift      # 便签编辑器（标题 + 内容 + 标签）
│   │   ├── SearchBar.swift           # 搜索输入框
│   │   └── MiniBarView.swift         # 迷你悬浮条
│   └── Window/
│       ├── WindowCoordinator.swift   # 主窗口与迷你面板协调
│       └── MiniPanelDelegate.swift   # 迷你面板事件处理
├── script/
│   ├── build_and_run.sh         # 构建打包运行脚本
│   └── check_windows.swift      # 窗口调试工具
└── Package.swift                # SwiftPM 包定义
```

### 技术选型

| 层面 | 技术 | 说明 |
| --- | --- | --- |
| **UI 框架** | SwiftUI | 声明式界面，macOS 14+ 原生组件 |
| **窗口控制** | AppKit (NSPanel/NSWindow) | 底层窗口层级、置顶、动画 |
| **状态管理** | @Observable (Swift Observation) | 响应式数据流 |
| **持久化** | JSON 文件 | 轻量本地存储，无需数据库 |
| **全局热键** | Carbon RegisterEventHotKey | 系统级快捷键，无需辅助功能权限 |
| **构建工具** | Swift Package Manager | 原生包管理，无 Xcode 工程依赖 |

### 数据存储

```
~/Library/Application Support/CopyNote/
├── notes.json    # 便签数据（标题、内容、标签、时间戳）
└── prefs.json    # 偏好设置（排序方式）
```

## 🛠️ 开发

### 构建与运行

```bash
# 编译
swift build --disable-sandbox

# 构建打包并运行
bash script/build_and_run.sh run

# 调试模式（lldb）
bash script/build_and_run.sh --debug

# 查看运行日志
bash script/build_and_run.sh --logs
```

### 调试工具

```bash
# 检查应用窗口状态
CN_PID=$(pgrep -x CopyNote) swift script/check_windows.swift
```

## 📄 License

[MIT License](LICENSE) © 2026 [demario1201-creator](https://github.com/demario1201-creator)

---

<div align="center">

如果这个项目对你有帮助，欢迎 ⭐ Star 支持

[报告问题](https://github.com/demario1201-creator/CopyNote/issues) · [功能建议](https://github.com/demario1201-creator/CopyNote/discussions) · [查看 Release](https://github.com/demario1201-creator/CopyNote/releases)

</div>
