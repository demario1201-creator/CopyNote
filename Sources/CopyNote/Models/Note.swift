import Foundation

/// 便签数据模型。
struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var tags: [String] = []
    var createdAt: Date = .now
    var updatedAt: Date = .now
}
