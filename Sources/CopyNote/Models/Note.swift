import Foundation

/// 便签数据模型。
struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var tags: [String] = []
    /// 颜色主题：默认 "" → .default；其他值映射到 NoteColorTheme
    var colorHex: String = ""
    /// 星标：置顶显示（F3）
    var isPinned: Bool = false
    /// 锁定：删除前需要二次确认（F3）
    var isLocked: Bool = false
    var createdAt: Date = .now
    var updatedAt: Date = .now

    /// 成员构造器（显式声明：因 decode init 覆盖了编译器自动合成）
    init(id: UUID = UUID(),
         title: String,
         content: String,
         tags: [String] = [],
         colorHex: String = "",
         isPinned: Bool = false,
         isLocked: Bool = false,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.colorHex = colorHex
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, tags, colorHex, isPinned, isLocked, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }
}
