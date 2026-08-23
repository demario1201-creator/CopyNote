import AppKit
import SwiftUI

/// 窗口协调器：拥有主窗口与迷你面板，负责置顶、隐藏为悬浮条、边缘吸附、悬停窥视。
/// 亦是主窗口的 NSWindowDelegate（关闭主窗口 → 进入迷你模式）。
final class WindowCoordinator: NSObject {
    let store: NoteStore

    private(set) var mainWindow: NSWindow!
    private(set) var miniPanel: NSPanel!
    private(set) var miniContainer: MiniContainerView!
    private let miniDelegate = MiniPanelDelegate()

    private(set) var isPinned = false
    private(set) var isMini = false
    private(set) var isPeeking = false
    private(set) var isDraggingMini = false
    private(set) var isAnimatingMini = false
    private(set) var lastSnap: SnapResult?

    private let miniSize = NSSize(width: 56, height: 220)

    init(store: NoteStore) {
        self.store = store
        super.init()
    }

    func setupWindows() {
        // 主窗口
        let mainRect = NSRect(x: 0, y: 0, width: 360, height: 520)
        let main = NSWindow(contentRect: mainRect,
                            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        main.title = "CopyNote"
        main.titlebarAppearsTransparent = true
        main.titleVisibility = .hidden
        main.isReleasedWhenClosed = false
        main.contentView = NSHostingView(
            rootView: MainNoteListView(
                onTogglePin: { [weak self] in self?.togglePin() },
                onHide: { [weak self] in self?.hideToMini() }
            ).environment(store)
        )
        main.delegate = self
        main.center()
        self.mainWindow = main

        // 迷你面板
        let miniRect = NSRect(origin: .zero, size: miniSize)
        let panel = NSPanel(contentRect: miniRect,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        let container = MiniContainerView(rootView: AnyView(MiniBarView().environment(store)))
        container.coordinator = self
        panel.contentView = container
        self.miniContainer = container
        self.miniPanel = panel
        miniDelegate.coordinator = self
        panel.delegate = miniDelegate

        main.makeKeyAndOrderFront(nil)
    }

    // MARK: - Main window actions

    func togglePin() {
        isPinned.toggle()
        mainWindow.level = isPinned ? .floating : .normal
    }

    func hideToMini() {
        guard !isMini else { return }
        isMini = true
        mainWindow.orderOut(nil)
        showMiniPanel()
    }

    func expand() {
        if isMini {
            miniPanel.orderOut(nil)
            isMini = false
            isPeeking = false
        }
        mainWindow.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 全局快捷键触发：主窗口可见则隐藏为 mini，否则展开。
    func toggleExpand() {
        if mainWindow.isVisible && !isMini {
            hideToMini()
        } else {
            expand()
        }
    }

    // MARK: - Mini panel geometry

    private func showMiniPanel() {
        let screen = mainWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let vf = screen?.visibleFrame else { return }
        let snap: SnapResult
        if let last = lastSnap {
            snap = EdgeSnapService.reframe(last, visibleFrame: vf,
                                           width: miniSize.width, height: miniSize.height)
        } else {
            snap = EdgeSnapService.defaultSnap(visibleFrame: vf,
                                               width: miniSize.width, height: miniSize.height)
        }
        lastSnap = snap
        isPeeking = false
        miniPanel.setFrame(snap.restFrame, display: true)
        miniPanel.orderFrontRegardless()
    }

    func peekIn() {
        guard isMini, !isPeeking, let snap = lastSnap else { return }
        isPeeking = true
        animateFrame(snap.peekFrame)
    }

    func peekOut() {
        guard isMini, isPeeking, let snap = lastSnap else { return }
        isPeeking = false
        animateFrame(snap.restFrame)
    }

    func beginDrag() { isDraggingMini = true }
    func endDrag() { isDraggingMini = false }

    /// 拖动结束后吸附到休息态；若光标仍在条上则 peek。
    func settleMini() {
        guard isMini else { return }
        snapMiniToEdge(animate: true)
        let mouseLoc = NSEvent.mouseLocation
        if miniPanel.frame.contains(mouseLoc) {
            peekIn()
        }
    }

    /// 依据当前面板 frame 计算最近边缘并吸附到休息态。
    func snapMiniToEdge(animate: Bool) {
        guard isMini,
              let screen = miniPanel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let frame = miniPanel.frame
        let snap: SnapResult
        if let result = EdgeSnapService.snap(forWindowFrame: frame, visibleFrame: vf) {
            snap = result
        } else {
            let edge: MiniEdge = frame.midX < vf.midX ? .left : .right
            snap = EdgeSnapService.frames(for: edge, y: frame.minY, visibleFrame: vf,
                                          height: frame.height, width: frame.width)
        }
        lastSnap = snap
        let canonical = isPeeking ? snap.peekFrame : snap.restFrame
        if animate {
            animateFrame(canonical)
        } else {
            miniPanel.setFrame(canonical, display: true)
        }
    }

    private func animateFrame(_ target: CGRect) {
        isAnimatingMini = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            self.miniPanel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimatingMini = false
            // 动画结束后对齐到规范矩形，防止浮点累积漂移
            if let snap = self.lastSnap {
                let canonical = self.isPeeking ? snap.peekFrame : snap.restFrame
                if self.miniPanel.frame != canonical {
                    self.miniPanel.setFrame(canonical, display: true)
                }
            }
        })
    }

    /// 显示器参数变化时按既有 snap 重新夹取；若屏幕丢失则回退到主屏默认吸附。
    func reflowOnScreenChange() {
        guard isMini else { return }
        let current = miniPanel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = current else { return }
        let vf = screen.visibleFrame
        if let snap = lastSnap {
            let reframed = EdgeSnapService.reframe(snap, visibleFrame: vf,
                                                    width: miniSize.width, height: miniSize.height)
            lastSnap = reframed
            let canonical = isPeeking ? reframed.peekFrame : reframed.restFrame
            miniPanel.setFrame(canonical, display: true)
        } else {
            let snap = EdgeSnapService.defaultSnap(visibleFrame: vf,
                                                   width: miniSize.width, height: miniSize.height)
            lastSnap = snap
            miniPanel.setFrame(snap.restFrame, display: true)
        }
    }
}

extension WindowCoordinator: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow, w === mainWindow else { return }
        // 关闭主窗口（红点）→ 进入迷你模式而非退出
        hideToMini()
    }
}
