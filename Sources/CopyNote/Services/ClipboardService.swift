import AppKit

/// 系统剪切板复制服务。
@MainActor
enum ClipboardService {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
