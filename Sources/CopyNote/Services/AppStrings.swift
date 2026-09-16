import Foundation

/// 语言偏好：持久化到 UserDefaults，支持即时切换
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    /// "system" = 跟随系统；"zh" = 简体中文；"en" = English
    var preference: String {
        didSet { UserDefaults.standard.set(preference, forKey: "copynote.language") }
    }

    private init() {
        self.preference = UserDefaults.standard.string(forKey: "copynote.language") ?? "system"
    }

    var isChinese: Bool {
        switch preference {
        case "zh": return true
        case "en": return false
        default:
            return Locale.current.language.languageCode?.identifier == "zh"
        }
    }
}

/// 简易 i18n：基于 LanguageManager 切换中文/英文。
/// SwiftPM 可执行程序无 .lproj bundle，用程序化 string table 替代。
enum AppStrings {
    private static var isChinese: Bool { LanguageManager.shared.isChinese }

    // MARK: - App / Menu
    enum App {
        static let name = "CopyNote"
        static let showMainWindow = tr("显示主窗口", "Show Main Window")
        static let hideToMiniBar = tr("隐藏为悬浮条", "Hide as Mini Bar")
        static let importJSON = tr("导入便签 JSON", "Import Notes JSON")
        static let exportAll = tr("导出全部便签", "Export All Notes")
        static let exportSingle = tr("导出此便签", "Export This Note")
        static let addTag = tr("添加标签", "Add Tag")
        static let removeTag = tr("移除标签", "Remove Tag")
        static let quit = tr("退出 CopyNote", "Quit CopyNote")
        static let settings = tr("设置…", "Settings…")
        static let hotkeySettings = tr("快捷键设置…", "Hotkey Settings…")
        static let importFailedTitle = tr("导入失败", "Import Failed")
        static let importFailedMsg = tr("无法解析所选文件，请确认是 CopyNote 导出的 JSON 格式。", "Could not parse the selected file. Please ensure it's a valid CopyNote JSON export.")
        static let importFileUnreadable = tr("无法读取文件", "Could not read file")
        static let exportFailedTitle = tr("导出失败", "Export Failed")
        static let exportFailedMsg = tr("写入文件失败，请检查目标位置权限。", "Failed to write file. Please check the destination permissions.")
        static let importSuccess = tr("成功导入 %d 条便签", "Successfully imported %d notes")
    }

    // MARK: - Toolbar
    enum Toolbar {
        static let newNote = tr("新建便签", "New Note")
        static let importExport = tr("导入/导出便签 JSON", "Import/Export Notes JSON")
        static let sort = tr("排序：单击切换 / 长按展开", "Sort: Click to cycle / Long press for menu")
        static let compact = tr("紧凑显示", "Compact View")
        static let expanded = tr("展开显示", "Expanded View")
        static let groupByTag = tr("按标签分组视图", "Group by Tag")
        static let ungroup = tr("取消分组（扁平列表）", "Ungroup (Flat List)")
        static let pinWindow = tr("窗口置顶", "Pin Window on Top")
        static let unpinWindow = tr("取消置顶", "Unpin Window")
        static let hideMini = tr("隐藏为悬浮条", "Hide as Mini Bar")
        static let clipboardHistory = tr("复制历史", "Clipboard History")
    }

    // MARK: - Note Actions
    enum NoteAction {
        static let edit = tr("编辑", "Edit")
        static let delete = tr("删除", "Delete")
        static let duplicate = tr("复制副本", "Duplicate")
        static let copyContent = tr("复制内容", "Copy Content")
        static let favorite = tr("收藏", "Favorite")
        static let unfavorite = tr("取消收藏", "Unfavorite")
        static let lock = tr("锁定便签", "Lock Note")
        static let unlock = tr("解除锁定", "Unlock Note")
    }

    // MARK: - Empty State
    enum Empty {
        static let noNotes = tr("还没有便签", "No notes yet")
        static let noMatch = tr("无匹配结果", "No matching results")
        static let createHint = tr("点击下方按钮创建你的第一条便签，或使用快捷键随时呼出。", "Click below to create your first note, or use the hotkey anytime.")
    }

    // MARK: - Search
    enum Search {
        static let placeholder = tr("搜索便签…", "Search notes…")
    }

    // MARK: - Editor
    enum Editor {
        static let title = tr("编辑便签", "Edit Note")
        static let titlePlaceholder = tr("便签标题…", "Note title…")
        static let contentPlaceholder = tr("写点什么…", "Write something…")
        static let contentHint = tr("开始书写内容…支持换行，Markdown 可选。", "Start writing… Supports line breaks, optional Markdown.")
        static let preview = tr("预览", "Preview")
        static let edit = tr("编辑", "Edit")
        static let done = tr("保存", "Save")
        static let cancel = tr("取消", "Cancel")
        static let tags = tr("标签", "Tags")
        static let tagPlaceholder = tr("输入标签名…", "Enter tag name…")
        static let tagInputHint = tr("添加标签，回车确认", "Add tag, press Enter to confirm")
        static let frequentlyUsed = tr("常用标签", "Frequently Used")
        static let frequentlyUsedShort = tr("常用:", "Frequent:")
        static let wordCount = tr("字", "words")
        static let charCount = tr("字符", "chars")
    }

    // MARK: - MiniBar
    enum MiniBar {
        static let noNotes = tr("还没有便签", "No notes yet")
        static let createFirst = tr("主窗口新建第一条吧", "Create your first note in the main window")
        static let copied = tr("已复制", "Copied")
        static let copy = tr("复制", "Copy")
        static let untitled = tr("无标题", "Untitled")
        static let emptyContent = tr("（内容为空）", "(Empty)")
    }

    // MARK: - Clipboard History
    enum History {
        static let title = tr("复制历史（最多 10 条）", "Clipboard History (max 10)")
        static let empty = tr("复制历史是空的", "Clipboard history is empty")
        static let emptyHint = tr("在主窗口或迷你条复制一次便签内容即可入史", "Copy note content from the main window or mini bar to add to history")
        static let clear = tr("清空", "Clear")
        static let refresh = tr("刷新", "Refresh")
        static let recopy = tr("复制", "Recopy")
        static let copied = tr("已复制", "Copied")
        static let emptyNote = tr("（无标题便签）", "(Untitled note)")
        static let emptyContent = tr("（内容为空）", "(Empty)")
        static let recopyHint = tr("再次复制这条内容 ⌘ 点击列表任意处也可复制", "Recopy this content ⌘ Click anywhere in the list to copy")
        static let yesterday = tr("昨天", "Yesterday")
        static let daysAgo = tr("天前", "days ago")
    }

    // MARK: - Hotkey Settings
    enum Hotkey {
        static let title = tr("快捷键设置", "Hotkey Settings")
        static let recording = tr("按下快捷键…", "Press key combination…")
        static let record = tr("录制", "Record")
        static let stop = tr("停止", "Stop")
        static let reset = tr("重置", "Reset")
        static let resetAll = tr("全部重置", "Reset All")
        static let conflict = tr("冲突！", "Conflict!")
        static let conflictWith = tr("与「", "Conflicts with \"")
        static let close = tr("关闭", "Close")
        static let global = tr("全局", "Global")
        static let inApp = tr("应用内", "In-App")
        static let toggleWindow = tr("切换主窗口/悬浮条", "Toggle Main/Mini Window")
        static let newNote = tr("新建便签", "New Note")
        static let edit = tr("编辑便签", "Edit Note")
        static let duplicate = tr("复制副本", "Duplicate Note")
        static let copyContent = tr("复制便签内容", "Copy Note Content")
        static let deleteNote = tr("删除便签", "Delete Note")
        static let history = tr("打开复制历史", "Open Clipboard History")
    }

    // MARK: - Delete Confirm
    enum Delete {
        static let lockedTitle = tr("删除已锁定的便签", "Delete Locked Note")
        static let lockedMessage = tr("已锁定，确定要删除吗？此操作不可撤销。", "is locked. Are you sure you want to delete it? This cannot be undone.")
        static let confirm = tr("删除", "Delete")
        static let cancel = tr("取消", "Cancel")
    }

    // MARK: - Settings Panel
    enum Settings {
        static let title = tr("设置", "Settings")
        static let hotkey = tr("快捷键", "Hotkeys")
        static let language = tr("语言", "Language")
        static let backup = tr("自动备份", "Auto Backup")
        static let about = tr("关于", "About")
        static let systemDefault = tr("跟随系统", "System Default")
        static let chinese = tr("简体中文", "简体中文")
        static let english = tr("English", "English")
        static let languageHint = tr("切换后立即生效，无需重启", "Takes effect immediately, no restart needed")
        static let backupLocation = tr("备份位置", "Backup Location")
        static let openInFinder = tr("在访达中打开", "Open in Finder")
        static let backupNow = tr("立即备份", "Backup Now")
        static let backupList = tr("备份记录", "Backup Files")
        static let noBackups = tr("暂无备份文件", "No backup files yet")
        static let autoBackupDesc = tr("每次保存便签时自动备份当天数据，保留最近 7 天。", "Auto-backups today's data on every save, keeps the last 7 days.")
        static let restartApp = tr("重启应用", "Restart App")
        static let quitApp = tr("退出应用", "Quit App")
        static let restartConfirm = tr("确定要重启 CopyNote 吗？", "Restart CopyNote?")
        static let quitConfirm = tr("确定要退出 CopyNote 吗？", "Quit CopyNote?")
        static let version = tr("版本", "Version")
        static let appDesc = tr("轻量级 macOS 便签管理工具", "Lightweight macOS sticky notes manager")
        static let fileSize = tr("大小", "Size")
        static let date = tr("日期", "Date")
        static let name = tr("文件名", "Name")
        static let restore = tr("恢复", "Restore")
        static let restoreConfirm = tr("确定要恢复此备份吗？当前数据将被替换。", "Restore this backup? Current data will be replaced.")
        static let deleteBackup = tr("删除", "Delete")
    }

    // MARK: - Grouped View
    enum Group {
        static let uncategorized = tr("未分类", "Uncategorized")
        static let all = tr("全部", "All")
    }

    // MARK: - Sort Orders
    enum Sort {
        static let updatedDesc = tr("最近更新", "Recent Updates")
        static let updatedAsc = tr("最早更新", "Oldest Updates")
        static let createdDesc = tr("最近创建", "Recent Creates")
        static let createdAsc = tr("最早创建", "Oldest Creates")
        static let titleAsc = tr("标题 A→Z", "Title A→Z")
        static let titleDesc = tr("标题 Z→A", "Title Z→A")
    }

    // MARK: - Backup
    enum Backup {
        static let backupCreated = tr("自动备份已创建", "Auto backup created")
    }

    // MARK: - Accessibility
    enum A11y {
        static let noteRow = tr("便签", "Note")
        static let noteRowHint = tr("单击复制内容", "Click to copy content")
        static let searchField = tr("搜索便签", "Search notes")
        static let swatchCopy = tr("复制", "Copy")
        static let dragBar = tr("拖动吸附到边缘", "Drag to snap to edge")
    }

    // MARK: - Helper

    /// 中/英二选一
    private static func tr(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}

/// 为 SortOrder 提供本地化 rawValue 的扩展
extension NoteStore.SortOrder {
    var localizedName: String {
        switch self {
        case .updatedDesc: return AppStrings.Sort.updatedDesc
        case .updatedAsc:  return AppStrings.Sort.updatedAsc
        case .createdDesc: return AppStrings.Sort.createdDesc
        case .createdAsc:  return AppStrings.Sort.createdAsc
        case .titleAsc:    return AppStrings.Sort.titleAsc
        case .titleDesc:   return AppStrings.Sort.titleDesc
        }
    }
}
