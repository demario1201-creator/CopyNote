import SwiftUI

// MARK: - U3 标签胶囊视觉统一

/// 标签胶囊的强调层级
enum TagCapsuleEmphasis {
    /// 选中态（筛选条当前选中 / hover 高亮）：更强填充 + 描边
    case selected
    /// 普通态（编辑器已添加标签 / 列表内标签展示）
    case normal
    /// 次要态（弱化提示，如「常用标签」快速条）
    case secondary
}

/// 统一的标签胶囊视觉：一致的填充、描边、线宽，三处共用
struct TagCapsuleStyle: ViewModifier {
    var emphasis: TagCapsuleEmphasis = .normal
    var accent: Color = Color.accentColor

    func body(content: Content) -> some View {
        content
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
    }

    private var fill: Color {
        switch emphasis {
        case .selected:  return accent.opacity(0.22)
        case .normal:    return accent.opacity(0.12)
        case .secondary: return Color.primary.opacity(0.06)
        }
    }

    private var stroke: Color {
        switch emphasis {
        case .selected:  return accent.opacity(0.42)
        case .normal:    return accent.opacity(0.24)
        case .secondary: return accent.opacity(0.2)
        }
    }

    private var lineWidth: CGFloat {
        switch emphasis {
        case .selected:  return 1.0
        case .normal:    return 0.7
        case .secondary: return 0.5
        }
    }
}

extension View {
    func tagCapsuleStyle(_ emphasis: TagCapsuleEmphasis = .normal,
                         accent: Color = Color.accentColor) -> some View {
        modifier(TagCapsuleStyle(emphasis: emphasis, accent: accent))
    }
}