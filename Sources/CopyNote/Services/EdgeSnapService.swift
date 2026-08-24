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
/// 仅左/右水平边缘、容差吸附、休息态半隐藏、peek 展开宽度 180、canonical snap 防 DPI 漂移。
enum EdgeSnapService {
    static let snapThreshold: CGFloat = 30
    static let restVisibleFraction: CGFloat = 0.34
    static let peekWidth: CGFloat = 180

    /// 拖动结束时调用：若靠近某一边缘（容差内），返回该边缘的吸附结果；否则返回 nil。
    static func snap(forWindowFrame frame: CGRect, visibleFrame: CGRect) -> SnapResult? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let distLeft = abs(center.x - visibleFrame.minX)
        let distRight = abs(visibleFrame.maxX - center.x)
        let nearest = min(distLeft, distRight)
        guard nearest <= snapThreshold + frame.width / 2 else { return nil }
        let edge: MiniEdge = distLeft <= distRight ? .left : .right
        return frames(for: edge, y: frame.minY, visibleFrame: visibleFrame,
                       height: frame.height, restWidth: frame.width)
    }

    /// 进入迷你模式时的默认吸附（默认右边缘、垂直居中）。
    static func defaultSnap(visibleFrame: CGRect, width: CGFloat, height: CGFloat,
                            edge: MiniEdge = .right) -> SnapResult {
        let y = visibleFrame.midY - height / 2
        return frames(for: edge, y: y, visibleFrame: visibleFrame,
                      height: height, restWidth: width)
    }

    /// 依据既有 snap 的边缘，在新 visibleFrame 下重新夹取（显示器变化时复位）。
    static func reframe(_ snap: SnapResult, visibleFrame: CGRect, width: CGFloat, height: CGFloat) -> SnapResult {
        let y = min(max(snap.restFrame.minY, visibleFrame.minY), visibleFrame.maxY - height)
        return frames(for: snap.edge, y: y, visibleFrame: visibleFrame,
                       height: height, restWidth: width)
    }

    static func frames(for edge: MiniEdge, y: CGFloat, visibleFrame: CGRect,
                       height: CGFloat, restWidth: CGFloat) -> SnapResult {
        let clampedY = max(visibleFrame.minY, min(y, visibleFrame.maxY - height))
        let visiblePart = restWidth * restVisibleFraction
        let restX: CGFloat
        let peekX: CGFloat
        switch edge {
        case .left:
            // rest：左侧藏于屏外，仅 visiblePart 露出
            restX = visibleFrame.minX - (restWidth - visiblePart)
            // peek：展开到 peekWidth，右边贴屏内左边缘
            peekX = visibleFrame.minX
        case .right:
            restX = visibleFrame.maxX - visiblePart
            peekX = visibleFrame.maxX - peekWidth
        }
        return SnapResult(edge: edge,
                          restFrame: CGRect(x: restX, y: clampedY, width: restWidth, height: height),
                          peekFrame: CGRect(x: peekX, y: clampedY, width: peekWidth, height: height))
    }
}
