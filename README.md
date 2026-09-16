<p align="center">
  <a href="#-为什么是-copynote">亮点</a> ·
  <a href="#-快速开始">安装</a> ·
  <a href="#-快捷键">快捷键</a> ·
  <a href="#-使用指南">指南</a> ·
  <a href="#-技术选型">技术</a> ·
  <a href="#-license">License</a>
</p>

<div align="center">

<img src="docs/copynote-icon.png" width="120" height="120" alt="CopyNote" />

# CopyNote

### 轻若鸿毛的 macOS 便签 · 单击即复制，即取即用

原生 SwiftUI + AppKit 打造，常驻菜单栏，把「复制」这件事做到一键之快。

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue?logo=apple&logoColor=white)](https://github.com/demario1201-creator/CopyNote)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-blue)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![零依赖](https://img.shields.io/badge/dependencies-none-brightgreen)]()
[![Stars](https://img.shields.io/github/stars/demario1201-creator/CopyNote?style=social)](https://github.com/demario1201-creator/CopyNote/stargazers)

**⚡ 单击即复制** · **🫧 迷你悬浮条** · **🎨 色卡直达** · **🔒 纯本地隐私** · **🪶 原生轻量**

</div>

---

## ✨ 为什么是 CopyNote

> 别的便签要「打开 App → 翻找 → 选中 → 复制」，CopyNote 把这一切压缩成 **一次点击**。

### ⚡ 快，是它的本能

- 🖱️ **单击即复制** —— 点任意便签或色卡圆点，内容直入剪贴板，绿色闪光反馈
- 🫧 **迷你悬浮条** —— 窗口收成屏幕边缘一条彩标：悬停预览、滚动翻页、点击即取，全程不展开窗口
- 🖐️ **自由拖动** —— 按住迷你条顶部拖拽点，可移到屏幕任意位置；松开自动吸附到最近边缘，高度随你选
- 🎨 **色卡直达** —— 圆点即「最近颜色」，单击复制最近内容；右键菜单，同色便签任你挑
- ⌨️ **全局热键** —— `⌥ ⌘ N` 任意应用唤出 / 收起，7 个动作全部可自定义、冲突自动提示

### 🧠 越用越顺手

- 📝 **Markdown 渲染** —— 标题 / 粗体 / 链接 / 行内代码开箱即用，编辑实时预览
- 👁️ **悬停预览** —— 主列表鼠标移到便签正文，完整内容以浮窗浮现，移开消失
- 🏷️ **多标签 + 分组** —— 无限标签、按使用频率排序、一键分组视图
- 🔍 **智能搜索** —— 多关键词空格分隔（AND 逻辑），跨标题 / 内容 / 标签秒级命中
- ⭐ **收藏 & 锁定** —— 星标便签永远置顶；锁定便签删除前二次确认，防误删
- 📋 **复制历史** —— 最近 10 条自动留档，`⌘ ⇧ V` 随手回捞

### 🔒 隐私与轻量

- 🔒 **纯本地存储** —— 数据只在本机，零上传、零账号、零追踪
- 💾 **每日自动备份** —— 7 天快照轮换，手动备份 / 一键恢复
- 🪶 **原生零依赖** —— SwiftUI + AppKit 本尊，没有 Electron，没有第三方运行时
- 🌐 **双语界面** —— 简体中文 / English 即时切换

### 🎨 赏心悦目

窗口置顶 📌 · 边缘吸附 🧲 · 主窗口↔悬浮条丝滑 morph 🃏 · 卡片 hover、折叠过渡、复制闪光 🎞️

---

## 📦 快速开始

### 方式一：下载 Release（推荐）

下载最新 [Release](https://github.com/demario1201-creator/CopyNote/releases) 的 `CopyNote.zip` → 解压拖入「应用程序」即可。

<details>
<summary>⚠️ 首次打开被 macOS 拦截怎么办？</summary>

这是 macOS Gatekeeper 对**未签名 / 未公证**第三方应用的正常保护，任选其一（推荐①，只需一次）：

**① 右键 → 打开（最快）**
按住 `Control` 单击 `CopyNote.app` → **打开** → 再次确认 → 之后双击正常启动。

**② 系统设置放行**
「系统设置 → 隐私与安全性」→ 找到提示 → **仍要打开** → 二次确认。

**③ 命令行去除隔离标记**

```bash
xattr -dr com.apple.quarantine /Applications/CopyNote.app
```

</details>

### 方式二：源码编译

```bash
git clone https://github.com/demario1201-creator/CopyNote.git
cd CopyNote
swift build --disable-sandbox
bash script/build_and_run.sh run
```

> 系统要求：macOS 14.0+ (Sonoma) · Apple Silicon

---

## ⌨️ 快捷键

> 全部可在「齿轮设置 → 快捷键」自定义，冲突自动提示。

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

## 🧭 使用指南

| 我想… | 怎么做 |
| --- | --- |
| 新建便签 | 工具栏 ➕ 或 `⌘ N` |
| 复制内容 | 单击便签行 / 迷你条色点，即入剪贴板 |
| 查看完整内容 | 鼠标悬停便签正文，浮窗预览 |
| 编辑 / 删除 | 悬停 ✏️ / 🗑️，或右键菜单，或 `⌘ E` / `⌫` |
| 收藏 / 锁定 | 便签 ⭐ / 🔒 图标，或右键菜单 |
| 搜索 / 筛选 | 顶部搜索框；标签胶囊 / 分组视图 |
| 切换排序 | 工具栏 ↕️（最近更新 / 标题 A→Z 等 6 种） |
| 移动迷你条 | 按住迷你条顶部拖拽点，移到任意位置后松开 |
| 置顶 / 收起 | 工具栏 📌 / ◫，收起后吸附屏幕边缘 |
| 导入 / 导出 | 工具栏「导入导出」，JSON 格式，支持单条与批量 |
| 复制历史 | 工具栏 🕐 或 `⌘ ⇧ V` |

---

## 🛠️ 技术选型

原生 **SwiftUI + AppKit**（NSPanel 窗口 / 层级 / 动画）· **@Observable** 状态管理 · **本地 JSON** 持久化 · **Carbon** 全局热键 —— 一个 SwiftPM 包，无 Xcode 工程依赖。

---

## 📄 License

[MIT](LICENSE) © 2026 [demario1201-creator](https://github.com/demario1201-creator)

---

<div align="center">

如果 CopyNote 帮你省下了每次「翻找 → 复制」的几秒钟，欢迎 Star 支持 ⭐

[🐛 报告问题](https://github.com/demario1201-creator/CopyNote/issues) · [💡 功能建议](https://github.com/demario1201-creator/CopyNote/discussions) · [📦 查看 Release](https://github.com/demario1201-creator/CopyNote/releases)

</div>
