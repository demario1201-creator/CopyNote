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

    /// 顶部「可拖动」条带高度：覆盖 dragBar + 图标，恰好让开下方色点/便签区。
    /// dragBar(~12) + padding top(8) + icon(15) ≈ 35，留余量到 40，避免盖住色点。
    private let dragStripHeight: CGFloat = 40

    /// 是否位于可拖动条带：rest 态（宽<100）整条顶部；peek 态左栏（<57.5）顶部。
    /// 其余区域（色点、便签行、计数）保留给 SwiftUI 手势（复制 / 展开）。
    private func isInDragRegion(_ point: NSPoint) -> Bool {
        let topStrip = point.y >= bounds.height - dragStripHeight
        if bounds.width < 100 { return topStrip }
        return point.x < 57.5 && topStrip
    }

    /// 让 SwiftUI 内容（NSHostingView）内部手势/onTapGesture 有机会处理：
    /// 点击落在哪块由 hostingView 决定；我们仍在 mouseDown 阶段按区域分发拖动逻辑。
    /// 顶部拖拽条带直接命中本视图——NSHostingView 会吞掉鼠标事件，
    /// 若不在此拦截，mouseDown 永远收不到，迷你条将无法拖动。
    /// 注意：hitTest 的 point 位于 superview 坐标系，需 convert 到本视图 bounds。
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        if isInDragRegion(localPoint) { return self }
        return super.hitTest(point)
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
        let localPoint = convert(event.locationInWindow, from: nil)
        // 仅顶部拖拽条带响应拖动；其余区域（色点复制 / 便签行复制 / 侧边展开）交给 SwiftUI
        guard isInDragRegion(localPoint) else {
            super.mouseDown(with: event)
            return
        }

        // nonactivating panel 上 performDrag 不可靠（面板不激活、不成为 key window，
        // 不会真正移动窗口），改用手动事件循环。
        // 关键：记录鼠标在窗口内的初始偏移量，每次用「事件鼠标屏幕位置 - 偏移量」定位窗口，
        // 使鼠标始终落在窗口内同一相对位置，避免轮询 NSEvent.mouseLocation 造成的跳变错位。
        coordinator?.beginDrag()
        let startOrigin = window.frame.origin
        let initialMouseScreen = window.convertPoint(toScreen: event.locationInWindow)
        let offset = NSPoint(x: initialMouseScreen.x - startOrigin.x,
                             y: initialMouseScreen.y - startOrigin.y)
        var moved = false

        while true {
            guard let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if next.type == .leftMouseDragged {
                let mouseScreen = window.convertPoint(toScreen: next.locationInWindow)
                window.setFrameOrigin(NSPoint(x: mouseScreen.x - offset.x,
                                              y: mouseScreen.y - offset.y))
                moved = true
            } else {
                break
            }
        }

        coordinator?.endDrag()

        let displacement = hypot(window.frame.origin.x - startOrigin.x,
                                 window.frame.origin.y - startOrigin.y)
        if moved && displacement > 3 {
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
