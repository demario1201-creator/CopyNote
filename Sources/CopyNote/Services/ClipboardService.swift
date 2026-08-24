import Foundation
import AppKit

/// 一次复制事件的历史项：记录复制的是哪条便签（可选），以及当时复制了什么文本快照。
@MainActor
struct ClipboardHistoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 对应便签 ID；如果来自 MiniBar 或以后「复制片段」可能为 nil
    var noteID: UUID?
    /// 当时的便签标题（纯展示）；MiniBar 可能没有就为空
    var noteTitle: String
    /// 复制时的实际内容文本快照（可重新复制）
    var contentSnapshot: String
    /// 复制发生时间
    var copiedAt: Date = .now

    init(id: UUID = UUID(), noteID: UUID? = nil, noteTitle: String = "", contentSnapshot: String, copiedAt: Date = .now) {
        self.id = id
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.contentSnapshot = contentSnapshot
        self.copiedAt = copiedAt
    }
}

/// 复制历史（内存 10 条循环队列；新复制项自动顶到最前，重复合并）。
/// 单独 @Observable，与 NoteStore 解耦。
@MainActor
@Observable final class ClipboardHistoryStore {
    static let shared = ClipboardHistoryStore()

    private(set) var items: [ClipboardHistoryItem] = []
    /// 最多保留多少条（循环覆盖）
    let maxCount: Int = 10

    private init() {}

    // MARK: - Write

    /// 记录一次复制事件。
    /// - 同一 noteID 的最近项：如果内容完全一致 → 移到最前并更新时间
    /// - 无 noteID 但 contentSnapshot 相同且已在列表最近一条：只更新时间（避免刷栈）
    /// - 否则插入最前；超长则删掉末尾
    func push(noteID: UUID? = nil, noteTitle: String = "", contentSnapshot: String) {
        guard !contentSnapshot.isEmpty else { return }
        defer { NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil) }
        // 1) 尝试合并：完全相同的内容最近一条（优先 noteID 匹配）
        if let idx = items.firstIndex(where: { it in
            (noteID != nil && it.noteID == noteID && it.contentSnapshot == contentSnapshot) ||
            (noteID == nil && it.contentSnapshot == contentSnapshot && it.noteID == nil)
        }) {
            var moved = items.remove(at: idx)
            moved.copiedAt = .now
            // 保留更完整的标题（如果老项有标题但这次给的是空）
            if !noteTitle.isEmpty { moved.noteTitle = noteTitle }
            items.insert(moved, at: 0)
            return
        }
        // 2) 不合并 → 插入最前
        let item = ClipboardHistoryItem(
            noteID: noteID, noteTitle: noteTitle, contentSnapshot: contentSnapshot, copiedAt: .now
        )
        items.insert(item, at: 0)
        // 3) 超量截断
        if items.count > maxCount {
            items.removeLast(items.count - maxCount)
        }
    }

    func removeAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
        NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
    }

    func remove(atOffsets offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        items.remove(atOffsets: offsets)
        NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
    }

    /// 把某条内容重新写入系统剪贴板（不重新 push 自己，避免刷栈；只更新时间移到最前）
    @discardableResult
    func recopy(_ item: ClipboardHistoryItem) -> Bool {
        let text = item.contentSnapshot
        guard !text.isEmpty else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        let ok = pb.setString(text, forType: .string)
        if ok {
            defer { NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil) }
            // 移到最前并刷新时间（体验：刚复制的在最上）
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                var moved = items.remove(at: idx)
                moved.copiedAt = .now
                items.insert(moved, at: 0)
            }
        }
        return ok
    }
}

/// 扩展 ClipboardService：每次 copy → 顺手进历史
@MainActor
enum ClipboardService {
    /// 复制文本到系统剪贴板，可选地写入复制历史（默认写）。
    @discardableResult
    static func copy(_ text: String, noteID: UUID? = nil, noteTitle: String = "", pushHistory: Bool = true) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        let ok = pb.setString(text, forType: .string)
        if ok && pushHistory {
            ClipboardHistoryStore.shared.push(noteID: noteID, noteTitle: noteTitle, contentSnapshot: text)
        }
        return ok
    }
}
