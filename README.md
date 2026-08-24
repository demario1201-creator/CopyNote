<div align="center">

<img src="docs/copynote-icon.png" width="140" height="140" alt="CopyNote logo" />

# CopyNote

### 轻若鸿毛的 macOS 便签 · 单击即复制，即取即用

原生 SwiftUI + AppKit 打造，常驻菜单栏，把「复制」这件事做到一键之快。

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue?logo=apple&logoColor=white)](https://github.com/demario1201-creator/CopyNote)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-blue)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/demario1201-creator/CopyNote?color=red)](https://github.com/demario1201-creator/CopyNote/releases)
[![零依赖](https://img.shields.io/badge/dependencies-none-brightgreen)]()

**快速复制** · **迷你悬浮条** · **本地隐私** · **无云依赖**

[功能亮点](#-为什么选择-copynote) · [安装](#-安装) · [快捷键](#-快捷键) · [使用指南](#-使用指南) · [技术栈](#-技术栈) · [License](#-license)

</div>

---

## ✨ 为什么选择 CopyNote

一张会「主动跑到你面前」的便签 —— 复制内容，从未如此顺手。

### ⚡ 极致效率

| | |
| --- | --- |
| 🖱️ **单击即复制** | 点击任意便签，内容立刻进入剪贴板，带绿色 flash 动画反馈 |
| 🫧 **迷你悬浮条** | 窗口收成屏幕边缘的一条彩色浮标，鼠标滑过即可预览 + 直接点选复制，不展开窗口 |
| ⌨️ **全局热键** | `⌥ ⌘ N` 任何应用中一键唤出 / 收起，键盘都不用离开 |
| 🎛️ **快捷键全自定义** | 7 个动作随心改键，自动检测快捷键冲突 |

### 🧠 会思考的便签

| | |
| --- | --- |
| 📝 **Markdown 渲染** | 标题 / 粗体 / 斜体 / 链接 / 行内代码 开箱即用，编辑器可实时预览 |
| 🏷️ **多标签 + 分组** | 无限标签、按使用频率排序、一键分组视图、标签胶囊统一视觉 |
| 🔍 **智能搜索** | 多关键词空格分隔（AND 逻辑），跨标题 / 内容 / 标签秒级命中 |
| ⭐ **收藏 & 锁定** | 星标便签永远置顶；锁定便签删除前二次确认，防止误删 |
| 📋 **复制历史** | 自动记录最近 10 条，随手回捞，`⌘ ⇧ V` 一键呼出 |

### 🛡️ 隐私与安心

| | |
| --- | --- |
| 🔒 **纯本地存储** | 数据只存于本机 JSON，零上传、零账号、零追踪 |
| 💾 **自动备份** | 每日自动快照 + 7 天保留，随时手动备份 / 一键恢复 |
| 🚫 **零依赖** | 第三方便签常拖家带口的 Electron，这里只有 SwiftUI + AppKit 本尊 |
| 🌐 **双语界面** | 简体中文 / English 即时切换 |

### 🎨 赏心悦目

| | |
| --- | --- |
| 📌 **窗口置顶** | 一键悬浮于所有窗口之上，参考常驻眼前 |
| 🧲 **边缘吸附** | 拖到屏幕边缘自动吸附，带弹性回弹动画 |
| 🃏 **窗口变形过渡** | 主窗口 ↔ 悬浮条丝滑 morph，切换不再生硬 |
| 🎞️ **细腻动效** | 卡片 hover、折叠过渡、复制闪光，处处顺滑 |

---

## 📦 安装

### 方式一：下载 Release（推荐）

1. 前往 [Releases 页面](https://github.com/demario1201-creator/CopyNote/releases) 下载最新 `CopyNote.zip`
2. 解压后将 `CopyNote.app` 拖入「应用程序」文件夹
3. 首次运行如被 Gatekeeper 拦截：
   - 打开「系统设置 → 隐私与安全性」→ 点击「仍要打开」

### 方式二：源码编译

```bash
git clone https://github.com/demario1201-creator/CopyNote.git
cd CopyNote
swift build --disable-sandbox
bash script/build_and_run.sh run
```

> **系统要求**：macOS 14.0+ (Sonoma) · Apple Silicon

---

## ⌨️ 快捷键

> 所有快捷键均可在「齿轮设置 → 快捷键」中自定义，冲突自动提示。

| 快捷键 | 功能 | 作用域 |
| --- | --- | --- |
| `⌥ ⌘ N` | 切换主窗口 / 悬浮条 | 全局 |
| `⌘ N` | 新建便签 | 应用内 |
| `⌘ E` | 编辑选中便签 | 应用内 |
| `⌘ D` | 复制一份副本 | 应用内 |
| `⌘ ↵` | 复制选中便签内容 | 应用内 |
| `⌘ ⇧ V` | 打开复制历史 | 应用内 |
| `⌫` | 删除选中便签 | 应用内 |

---

## 📖 使用指南

| 我想… | 怎么做 |
| --- | --- |
| **新建便签** | 工具栏 ➕ 或快捷键 `⌘ N` |
| **复制内容** | 单击便签行（或迷你悬浮条点选），内容即入剪贴板 |
| **编辑便签** | 悬停便签 → ✏️，或右键「编辑」，或 `⌘ E` |
| **删除便签** | 悬停便签 → 🗑️，或 `⌫`（锁定便签会二次确认） |
| **收藏 / 锁定** | 便签上的 ⭐ / 🔒 图标，或右键菜单 |
| **搜索便签** | 顶部搜索框（空格分隔多关键词） |
| **标签筛选 / 分组** | 点击搜索栏下方标签胶囊，或工具栏文件夹图标切换分组 |
| **切换排序** | 工具栏 ↕️ 图标（最近更新 / 标题 A→Z 等 6 种） |
| **置顶窗口** | 工具栏 📌 图标 |
| **收起悬浮条** | 工具栏 ◫ 图标，吸附到屏幕边缘 |
| **导入 / 导出** | 工具栏「导入导出」，JSON 格式，支持单条与批量 |
| **复制历史** | 工具栏 🕐 图标，或 `⌘ ⇧ V` |
| **打开设置** | 工具栏 ⚙️ 齿轮（快捷键 / 语言 / 自动备份 / 关于） |

---

## 🛠️ 技术栈

| 层面 | 选型 |
| --- | --- |
| **UI** | SwiftUI（macOS 14+ 原生组件） |
| **窗口控制** | AppKit（NSPanel 置顶、层级、动画） |
| **状态管理** | Swift Observation（`@Observable`） |
| **持久化** | 本地 JSON 文件 + 每日自动备份 |
| **全局热键** | Carbon `RegisterEventHotKey` |
| **构建** | Swift Package Manager（无 Xcode 工程依赖） |

> 更多技术细节与目录结构见项目源码。

---

## 📄 License

[MIT](LICENSE) © 2026 [demario1201-creator](https://github.com/demario1201-creator)

---

<div align="center">

如果 CopyNote 帮你省下了每一次「翻找 → 复制」的几秒钟，欢迎 ⭐ Star 支持 ⭐

[🐛 报告问题](https://github.com/demario1201-creator/CopyNote/issues) · [💡 功能建议](https://github.com/demario1201-creator/CopyNote/discussions) · [📦 查看 Release](https://github.com/demario1201-creator/CopyNote/releases)

</div>