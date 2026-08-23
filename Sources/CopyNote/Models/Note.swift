import Foundation

/// 便签数据模型。
struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var tags: [String] = []
    /// 颜色主题：默认 "" → .default；其他值映射到 NoteColorTheme
    var colorHex: String = ""
    var createdAt: Date = .now
    var updatedAt: Date = .now

    /// 成员构造器（显式声明：因 decode init 覆盖了编译器自动合成）
    init(id: UUID = UUID(),
         title: String,
         content: String,
         tags: [String] = [],
         colorHex: String = "",
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, tags, colorHex, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }
}
