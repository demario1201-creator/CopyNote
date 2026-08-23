import AppKit

/// 便签 JSON 导入/导出服务。
@MainActor
enum ImportExportService {

    // MARK: - Export

    /// 导出全部便签为 JSON 文件。
    static func exportAll(_ notes: [Note]) {
        export(notes, defaultName: "copynote-notes.json")
    }

    /// 导出单条便签为 JSON 文件。
    static func exportSingle(_ note: Note) {
        let name = note.title.isEmpty
            ? "copynote-note-\(note.id.uuidString.prefix(6)).json"
            : "\(note.title).json"
        export([note], defaultName: name)
    }

    private static func export(_ notes: [Note], defaultName: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(notes) else { return }

        let panel = NSSavePanel()
        panel.title = "导出便签"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Import

    /// 从 JSON 文件导入便签；冲突策略：ID 已存在则跳过。
    /// 返回成功导入的数量。
    @discardableResult
    static func importNotes(store: NoteStore) -> Int {
        let panel = NSOpenPanel()
        panel.title = "导入便签"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return 0 }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // 兼容两种格式：[Note] 数组 或 单个 Note 对象
        var imported: [Note] = []
        if let arr = try? decoder.decode([Note].self, from: data) {
            imported = arr
        } else if let single = try? decoder.decode(Note.self, from: data) {
            imported = [single]
        } else {
            return 0
        }

        let existingIDs = Set(store.notes.map(\.id))
        var count = 0
        for note in imported where !existingIDs.contains(note.id) {
            store.add(note)
            count += 1
        }
        return count
    }
}
