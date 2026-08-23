import Foundation
import AppKit

/// 迷你悬浮条的吸附边缘。
enum MiniEdge { case left, right }

/// 一次吸附的几何结果：休息态（半隐藏）与窥视态（滑出）的 frame。
struct SnapResult {
    let edge: MiniEdge
    let restFrame: CGRect
    let peekFrame: CGRect
}

/// 计算迷你悬浮条的停靠几何。参考 clawd-on-desk/src/mini.js + display-edge.js：
/// 仅左/右水平边缘、容差吸附、休息态半隐藏、peek 滑出偏移、canonical snap 防 DPI 漂移。
enum EdgeSnapService {
    static let snapThreshold: CGFloat = 30
    static let restVisibleFraction: CGFloat = 0.28
    static let peekOffset: CGFloat = 24

    /// 拖动结束时调用：若靠近某一边缘（容差内），返回该边缘的吸附结果；否则返回 nil。
    static func snap(forWindowFrame frame: CGRect, visibleFrame: CGRect) -> SnapResult? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let distLeft = abs(center.x - visibleFrame.minX)
        let distRight = abs(visibleFrame.maxX - center.x)
        let nearest = min(distLeft, distRight)
        // 中心距边缘需在 (容差 + 半宽) 以内才认为贴近边缘
        guard nearest <= snapThreshold + frame.width / 2 else { return nil }
        let edge: MiniEdge = distLeft <= distRight ? .left : .right
        return frames(for: edge, y: frame.minY, visibleFrame: visibleFrame,
                       height: frame.height, width: frame.width)
    }

    /// 进入迷你模式时的默认吸附（默认右边缘、垂直居中）。
    static func defaultSnap(visibleFrame: CGRect, width: CGFloat, height: CGFloat,
                            edge: MiniEdge = .right) -> SnapResult {
        let y = visibleFrame.midY - height / 2
        return frames(for: edge, y: y, visibleFrame: visibleFrame,
                      height: height, width: width)
    }

    /// 依据既有 snap 的边缘，在新 visibleFrame 下重新夹取（显示器变化时复位）。
    static func reframe(_ snap: SnapResult, visibleFrame: CGRect, width: CGFloat, height: CGFloat) -> SnapResult {
        let y = min(max(snap.restFrame.minY, visibleFrame.minY), visibleFrame.maxY - height)
        return frames(for: snap.edge, y: y, visibleFrame: visibleFrame,
                       height: height, width: width)
    }

    static func frames(for edge: MiniEdge, y: CGFloat, visibleFrame: CGRect,
                       height: CGFloat, width: CGFloat) -> SnapResult {
        let clampedY = max(visibleFrame.minY, min(y, visibleFrame.maxY - height))
        let visiblePart = width * restVisibleFraction
        let restX: CGFloat
        let peekX: CGFloat
        switch edge {
        case .left:
            // 左边缘：窗口左侧藏于屏外，仅 visiblePart 露出屏内
            restX = visibleFrame.minX - (width - visiblePart)
            peekX = restX + peekOffset
        case .right:
            restX = visibleFrame.maxX - visiblePart
            peekX = restX - peekOffset
        }
        return SnapResult(edge: edge,
                          restFrame: CGRect(x: restX, y: clampedY, width: width, height: height),
                          peekFrame: CGRect(x: peekX, y: clampedY, width: width, height: height))
    }
}
