import AppKit
import Carbon.HIToolbox
import Combine
import Observation

/// 可自定义的快捷键动作
enum HotkeyAction: String, Codable, CaseIterable, Identifiable {
    case toggleWindow   // 全局切换主窗口/迷你条
    case newNote         // 新建便签
    case edit            // 编辑选中便签
    case duplicate       // 复制副本
    case copyContent     // 复制便签内容
    case deleteNote      // 删除选中便签
    case history         // 打开复制历史

    var id: String { rawValue }

    /// 默认快捷键
    var defaultBinding: HotkeyBinding {
        switch self {
        case .toggleWindow: return .init(action: self, keyCode: UInt32(kVK_ANSI_N), modifiers: [.command, .option])
        case .newNote:      return .init(action: self, keyCode: UInt32(kVK_ANSI_N), modifiers: [.command])
        case .edit:          return .init(action: self, keyCode: UInt32(kVK_ANSI_E), modifiers: [.command])
        case .duplicate:     return .init(action: self, keyCode: UInt32(kVK_ANSI_D), modifiers: [.command])
        case .copyContent:   return .init(action: self, keyCode: UInt32(kVK_Return), modifiers: [.command])
        case .deleteNote:     return .init(action: self, keyCode: UInt32(kVK_Delete), modifiers: [])
        case .history:       return .init(action: self, keyCode: UInt32(kVK_ANSI_V), modifiers: [.command, .shift])
        }
    }

    /// 展示名（中/英通过 AppStrings）
    var displayName: String {
        switch self {
        case .toggleWindow: return AppStrings.Hotkey.toggleWindow
        case .newNote:      return AppStrings.Hotkey.newNote
        case .edit:          return AppStrings.Hotkey.edit
        case .duplicate:     return AppStrings.Hotkey.duplicate
        case .copyContent:   return AppStrings.Hotkey.copyContent
        case .deleteNote:    return AppStrings.Hotkey.deleteNote
        case .history:       return AppStrings.Hotkey.history
        }
    }

    /// 是否全局热键（Carbon RegisterEventHotKey）
    var isGlobal: Bool { self == .toggleWindow }
}

/// 快捷键绑定：keyCode + 修饰键
struct HotkeyBinding: Codable, Hashable {
    var action: HotkeyAction
    var keyCode: UInt32
    /// 存储 rawValue 以支持 Codable（NSEvent.ModifierFlags 不直接 conform）
    var modifiersRaw: UInt32

    init(action: HotkeyAction, keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.action = action
        self.keyCode = keyCode
        self.modifiersRaw = UInt32(modifiers.rawValue)
    }

    /// 便捷访问修饰键
    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw)) }
        set { modifiersRaw = UInt32(newValue.rawValue) }
    }

    /// Carbon 修饰键 mask（用于 RegisterEventHotKey）
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { m |= UInt32(optionKey) }
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    /// 人类可读的快捷键描述：⌘⇧V / ⌫ / ⌘↵ 等
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command)  { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    /// 将 macOS keyCode 转为可读名
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"; case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"; case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"; case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"; case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"; case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"; case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"; case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"; case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"; case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"; case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"; case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"; case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"; case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"; case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"; case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"; case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"; case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"; case kVK_ANSI_9: return "9"
        case kVK_Return: return "↵"; case kVK_Tab: return "⇥"
        case kVK_Space: return "␣"; case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"; case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"; case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"; case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"; case kVK_F2: return "F2"
        case kVK_F3: return "F3"; case kVK_F4: return "F4"
        case kVK_F5: return "F5"; case kVK_F6: return "F6"
        case kVK_F7: return "F7"; case kVK_F8: return "F8"
        case kVK_F9: return "F9"; case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default: return "Key\(keyCode)"
        }
    }

    /// 判断两个绑定是否"功能等价"（ keyCode + 有效修饰键相同）
    static func == (lhs: Self, rhs: Self) -> Bool {
        // 只比较有意义的修饰键（忽略 capsLock / function 等）
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        return lhs.keyCode == rhs.keyCode
            && (lhs.modifiers.intersection(mask)) == (rhs.modifiers.intersection(mask))
    }

    func hash(into hasher: inout Hasher) {
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        hasher.combine(keyCode)
        hasher.combine(modifiers.intersection(mask).rawValue)
    }
}

/// 快捷键配置仓库：@Observable，持久化到 ApplicationSupport/CopyNote/hotkeys.json
/// 支持冲突检测：setBinding 返回冲突的 action（如果有）
@MainActor
@Observable
final class HotkeyConfigStore {
    static let shared = HotkeyConfigStore()

    /// 所有动作的当前绑定（action.rawValue → binding）
    private(set) var bindings: [String: HotkeyBinding] = [:]

    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = support.appendingPathComponent("CopyNote", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("hotkeys.json")
        load()
    }

    // MARK: - Access

    func binding(for action: HotkeyAction) -> HotkeyBinding {
        bindings[action.rawValue] ?? action.defaultBinding
    }

    // MARK: - Conflict detection

    /// 检查给定 binding 是否与其他 action 冲突
    /// - Returns: 冲突的 action（如果有），不含自身
    func conflict(for binding: HotkeyBinding, excluding action: HotkeyAction) -> HotkeyAction? {
        for (key, existing) in bindings {
            guard key != action.rawValue else { continue }
            if existing == binding {
                return HotkeyAction(rawValue: key)
            }
        }
        // 也检查 default bindings（未被自定义的 action）
        for act in HotkeyAction.allCases {
            guard act != action, bindings[act.rawValue] == nil else { continue }
            if act.defaultBinding == binding {
                return act
            }
        }
        return nil
    }

    // MARK: - Write

    /// 设置某个 action 的快捷键绑定；返回冲突的 action（如果有）
    @discardableResult
    func setBinding(_ binding: HotkeyBinding) -> HotkeyAction? {
        let conflict = self.conflict(for: binding, excluding: binding.action)
        bindings[binding.action.rawValue] = binding
        save()
        return conflict
    }

    /// 重置某个 action 为默认快捷键
    func reset(_ action: HotkeyAction) {
        bindings.removeValue(forKey: action.rawValue)
        save()
    }

    /// 重置全部
    func resetAll() {
        bindings.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let dict = try? decoder.decode([String: HotkeyBinding].self, from: data) {
            bindings = dict
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(bindings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
