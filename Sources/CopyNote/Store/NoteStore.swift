import Foundation
import Observation

/// 便签存储：内存数组 + JSON 文件持久化 + 关键字搜索。
@Observable
final class NoteStore {
    enum SortOrder: String, Codable, CaseIterable, Identifiable {
        case updatedDesc = "最近更新"
        case updatedAsc  = "最早更新"
        case createdDesc = "最近创建"
        case createdAsc  = "最早创建"
        case titleAsc    = "标题 A→Z"
        case titleDesc   = "标题 Z→A"

        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .updatedDesc, .createdDesc: return "arrow.down"
            case .updatedAsc,  .createdAsc:  return "arrow.up"
            case .titleAsc:                  return "textformat.abc"
            case .titleDesc:                 return "textformat.abc.dottedunderline"
            }
        }
    }

    private(set) var notes: [Note] = []
    var sortOrder: SortOrder = .updatedDesc {
        didSet { sortInPlace() }
    }

    private let fileURL: URL
    private let prefsURL: URL

    init() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = support.appendingPathComponent("CopyNote", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("notes.json")
        self.prefsURL = dir.appendingPathComponent("prefs.json")
        loadPrefs()
        load()
        sortInPlace()
    }

    // MARK: - Persistence

    private func loadPrefs() {
        guard let data = try? Data(contentsOf: prefsURL) else { return }
        if let order = try? JSONDecoder().decode(SortOrder.self, from: data) {
            sortOrder = order
        }
    }

    private func savePrefs() {
        guard let data = try? JSONEncoder().encode(sortOrder) else { return }
        try? data.write(to: prefsURL, options: .atomic)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let arr = try? decoder.decode([Note].self, from: data) {
            notes = arr
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - CRUD

    @discardableResult
    func add(_ note: Note = Note(title: "", content: "")) -> Note {
        notes.insert(note, at: 0)
        sortInPlace()
        save()
        return note
    }

    func update(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var n = note
        n.updatedAt = .now
        notes[i] = n
        sortInPlace()
        save()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    // MARK: - F3 星标/锁定 + F5 Duplicate

    /// 切换便签的星标状态（会触发重排 + 持久化）。
    func togglePinned(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].isPinned.toggle()
        notes[i].updatedAt = .now
        sortInPlace()
        save()
    }

    /// 切换便签的锁定状态。
    func toggleLocked(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].isLocked.toggle()
        notes[i].updatedAt = .now
        save()
    }

    /// F5：复制一条新便签（ID/时间重置，保留标题/内容/标签/颜色/星标，不保留锁定）。
    @discardableResult
    func duplicate(_ note: Note) -> Note {
        var copy = Note(title: note.title.isEmpty ? "" : note.title + " 副本",
                        content: note.content,
                        tags: note.tags,
                        colorHex: note.colorHex,
                        isPinned: note.isPinned,
                        isLocked: false)
        notes.insert(copy, at: 0)
        sortInPlace()
        save()
        return copy
    }

    // MARK: - Sorting

    /// 变更排序顺序（会持久化到 prefs.json）。
    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        savePrefs()
    }

    private func sortInPlace() {
        // F3：星标（isPinned=true）始终排最前；组内按 sortOrder 排序。
        notes.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            switch sortOrder {
            case .updatedDesc: return a.updatedAt > b.updatedAt
            case .updatedAsc:  return a.updatedAt < b.updatedAt
            case .createdDesc: return a.createdAt > b.createdAt
            case .createdAsc:  return a.createdAt < b.createdAt
            case .titleAsc:    return (a.title.isEmpty ? a.content : a.title)
                .localizedCompare(b.title.isEmpty ? b.content : b.title) == .orderedAscending
            case .titleDesc:   return (a.title.isEmpty ? a.content : a.title)
                .localizedCompare(b.title.isEmpty ? b.content : b.title) == .orderedDescending
            }
        }
    }

    // MARK: - Search

    /// 多关键词（空格分隔，AND），跨标题与内容与标签，大小写/音调不敏感。
    func search(_ keyword: String) -> [Note] {
        let terms = keyword.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return notes }
        return notes.filter { note in
            terms.allSatisfy { term in
                note.title.localizedCaseInsensitiveContains(term)
                    || note.content.localizedCaseInsensitiveContains(term)
                    || note.tags.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
    }

    /// 按标签筛选（标签为 nil 时返回全部）。
    func filter(byTag tag: String?) -> [Note] {
        guard let tag, !tag.isEmpty else { return notes }
        return notes.filter { $0.tags.contains(tag) }
    }

    // MARK: - Tags

    /// 所有出现过的标签（去重 + 按使用频率排序）。
    var allTags: [String] {
        var counts: [String: Int] = [:]
        for note in notes {
            for tag in note.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }

    /// 给指定便签添加标签（去重）。
    func addTag(_ tag: String, to note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !notes[i].tags.contains(clean) else { return }
        notes[i].tags.append(clean)
        notes[i].updatedAt = .now
        sortInPlace()
        save()
    }

    /// 从指定便签移除标签。
    func removeTag(_ tag: String, from note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].tags.removeAll { $0 == tag }
        notes[i].updatedAt = .now
        sortInPlace()
        save()
    }
}
