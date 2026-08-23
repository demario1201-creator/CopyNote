import Foundation
import SwiftUI

/// 便签颜色主题：6 种预设（与物理便签本类似的暖色/冷色），用于卡片背景与编辑器纸色。
enum NoteColorTheme: String, Codable, CaseIterable, Identifiable {
    case `default`  // 无色（跟随系统灰）
    case yellow     // 暖黄：经典便签
    case green      // 薄荷绿
    case blue       // 晴空蓝
    case pink       // 樱花粉
    case orange     // 南瓜橙
    case purple     // 薰衣紫

    var id: String { rawValue }

    /// 便签名（中文）
    var name: String {
        switch self {
        case .default: return "默认"
        case .yellow:  return "柠檬黄"
        case .green:   return "薄荷绿"
        case .blue:    return "晴空蓝"
        case .pink:    return "樱花粉"
        case .orange:  return "南瓜橙"
        case .purple:  return "薰衣紫"
        }
    }

    /// 卡片背景淡色（10%）
    var cardTint: Color {
        switch self {
        case .default: return Color.primary.opacity(0.015)
        case .yellow:  return Color.yellow.opacity(0.14)
        case .green:   return Color.green.opacity(0.12)
        case .blue:    return Color.blue.opacity(0.12)
        case .pink:    return Color.pink.opacity(0.12)
        case .orange:  return Color.orange.opacity(0.12)
        case .purple:  return Color.purple.opacity(0.12)
        }
    }

    /// 编辑器纸张渐变主色（25%）
    var paperPrimary: Color {
        switch self {
        case .default: return Color.primary.opacity(0.02)
        case .yellow:  return Color.yellow.opacity(0.30)
        case .green:   return Color.green.opacity(0.22)
        case .blue:    return Color.blue.opacity(0.22)
        case .pink:    return Color.pink.opacity(0.22)
        case .orange:  return Color.orange.opacity(0.24)
        case .purple:  return Color.purple.opacity(0.22)
        }
    }

    /// 编辑器纸张渐变辅色（5%）
    var paperSecondary: Color {
        switch self {
        case .default: return Color.white.opacity(0.0)
        default:       return Color.white.opacity(0.25)
        }
    }

    /// 色卡圆点实色（用于色卡选择器）
    var swatch: Color {
        switch self {
        case .default: return Color.primary.opacity(0.18)
        case .yellow:  return Color(red: 0.98, green: 0.85, blue: 0.32)
        case .green:   return Color(red: 0.52, green: 0.85, blue: 0.62)
        case .blue:    return Color(red: 0.46, green: 0.72, blue: 0.98)
        case .pink:    return Color(red: 0.98, green: 0.65, blue: 0.75)
        case .orange:  return Color(red: 0.98, green: 0.72, blue: 0.45)
        case .purple:  return Color(red: 0.76, green: 0.62, blue: 0.95)
        }
    }

    /// 色卡外圈描边色
    var swatchStroke: Color {
        switch self {
        case .default: return Color.primary.opacity(0.3)
        default:       return swatch.opacity(0.75)
        }
    }
}

extension NoteColorTheme {
    /// 从 colorHex（String）安全构造；空或未知 → .default
    init(fromHex hex: String?) {
        guard let hex = hex, let t = NoteColorTheme(rawValue: hex) else {
            self = .default
            return
        }
        self = t
    }

    var toHex: String { rawValue }
}
