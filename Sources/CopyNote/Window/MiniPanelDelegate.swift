import AppKit
import SwiftUI

/// 迷你面板的内容视图：托管 SwiftUI 内容（纯展示），拦截鼠标事件，
/// 处理悬停（peek）、拖动（performDrag）、点击（侧边展开，peek 便签区复制）。
final class MiniContainerView: NSView {
    weak var coordinator: WindowCoordinator?

    private var trackingAreaRef: NSTrackingArea?
    private let hostingView: NSHostingView<AnyView>

    init(rootView: AnyView) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 让 SwiftUI 内容（NSHostingView）内部手势/onTapGesture 有机会处理：
    /// 点击落在哪块由 hostingView 决定；我们仍在 mouseDown 阶段按区域分发拖动逻辑。
    override func hitTest(_ point: NSPoint) -> NSView? {
        let sub = super.hitTest(point)
        // 只要命中在我们内部（包括 hostingView 及其子视图）就把事件留在本视图层级
        // 由 mouseDown 判断是否 performDrag 或交给 SwiftUI。
        return sub
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingAreaRef { removeTrackingArea(t) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) { coordinator?.peekIn() }
    override func mouseExited(with event: NSEvent) { coordinator?.peekOut() }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        let w = bounds.width
        let localPoint = convert(event.locationInWindow, from: nil)
        // 判断点击热区：
        // - rest 态（宽<100）→ 统一非便签区：拖动 / 未移动则 expand
        // - peek 态（宽≥100）：
        //   · x < 57.5 → 左栏 56 + 分隔线 → 侧边非便签区：拖动 / 未移动则 expand
        //   · x ≥ 57.5 → 右栏便签预览区：不拖动，交给 SwiftUI onTap 执行复制
        let isSidebar: Bool
        if w < 100 {
            isSidebar = true
        } else {
            isSidebar = localPoint.x < 57.5
        }
        guard isSidebar else {
            // 便签预览区：不 performDrag（否则会阻塞 onTapGesture），
            // 直接把事件向上传递（nextResponder → hostingView）让 SwiftUI onTap 生效。
            super.mouseDown(with: event)
            return
        }
        // 侧边区域：保留原有 performDrag + 移动判断 expand/settle 逻辑
        let origin = window.frame.origin
        coordinator?.beginDrag()
        window.performDrag(with: event)
        coordinator?.endDrag()
        let moved = hypot(window.frame.origin.x - origin.x,
                          window.frame.origin.y - origin.y) > 3
        if moved {
            coordinator?.settleMini()
        } else {
            coordinator?.expand()
        }
    }
}

/// 迷你面板的窗口代理：窗口移动时兜底吸附（拖动/动画/对齐canonical 期间跳过）。
final class MiniPanelDelegate: NSObject, NSWindowDelegate {
    weak var coordinator: WindowCoordinator?

    func windowDidMove(_ notification: Notification) {
        guard let c = coordinator, !c.isDraggingMini, !c.isAnimatingMini, !c.isAligningCanonical, c.isMini else { return }
        c.snapMiniToEdge(animate: true)
    }
}
