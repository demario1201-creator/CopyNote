import Foundation
import SwiftUI

/// 轻量 Markdown 渲染服务：基于 macOS 14 原生 AttributedString(markdown:)。
/// 无第三方依赖；渲染失败或语法不支持 → fallback 到纯文本。
enum MarkdownRenderer {

    /// 把 markdown 字符串转为 AttributedString；失败返回纯文本样式的 AttributedString。
    static func render(_ markdown: String) -> AttributedString {
        guard !markdown.isEmpty else { return AttributedString("") }
        // 原生 AttributedString(markdown:) 不支持常见的中文换行和转义边界，做一次预处理
        var sanitized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\t", with: "    ")
        // 末尾加换行可避免某些 AttributedString 截断 bug
        if !sanitized.hasSuffix("\n") { sanitized.append("\n") }
        if let rendered = try? AttributedString(markdown: sanitized,
                                                options: AttributedString.MarkdownParsingOptions(
                                                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                    failurePolicy: .returnPartiallyParsedIfPossible
                                                )) {
            return rendered
        }
        // 降级：按 full（含块语法）再试一次
        if let rendered = try? AttributedString(markdown: sanitized) {
            return rendered
        }
        // 最终降级：纯文本（系统 body 字体）
        var plain = AttributedString(markdown)
        plain.font = .system(.body)
        return plain
    }

    /// 渲染成「单行摘要」（去掉换行，限 maxLength 字符），用于列表预览场景。
    static func renderPreview(_ markdown: String, maxLength: Int = 160) -> AttributedString {
        let singleLine = markdown
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        let clipped: String
        if singleLine.count > maxLength {
            let idx = singleLine.index(singleLine.startIndex,
                                       offsetBy: maxLength,
                                       limitedBy: singleLine.endIndex) ?? singleLine.endIndex
            clipped = String(singleLine[..<idx]) + "…"
        } else {
            clipped = singleLine
        }
        return render(clipped)
    }
}
