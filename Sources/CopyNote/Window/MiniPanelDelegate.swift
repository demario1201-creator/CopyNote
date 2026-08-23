import AppKit
import SwiftUI

/// 迷你面板的内容视图：托管 SwiftUI 内容（纯展示），拦截鼠标事件，
/// 处理悬停（peek）、拖动（performDrag）、点击（展开）。
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

    /// 拦截所有命中测试：迷你条无内部控件，所有鼠标事件交给本视图处理（拖动/点击）。
    override func hitTest(_ point: NSPoint) -> NSView? { self }

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

/// 迷你面板的窗口代理：窗口移动时兜底吸附（拖动/动画期间跳过）。
final class MiniPanelDelegate: NSObject, NSWindowDelegate {
    weak var coordinator: WindowCoordinator?

    func windowDidMove(_ notification: Notification) {
        guard let c = coordinator, !c.isDraggingMini, !c.isAnimatingMini, c.isMini else { return }
        c.snapMiniToEdge(animate: true)
    }
}
