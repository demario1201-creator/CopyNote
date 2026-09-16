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

    /// Bug #1 修复：canonical 对齐期间设置，避免 windowDidMove 重入 snap 动画
    fileprivate(set) var isAligningCanonical = false
    /// Bug #2 修复：hideToMini 动画**开始前**保存主窗口原 frame；expand 时还原到此位置
    private var savedMainFrame: NSRect?

    private let miniSize = NSSize(width: 56, height: 220)

    init(store: NoteStore) {
        self.store = store
        super.init()
        // 监听 MiniBarView 侧边区域点击通知 → expand()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onMiniBarSidebarTapped),
            name: .miniBarSidebarTapped,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onMiniBarSidebarTapped() {
        // 只在迷你模式下响应；如果当前正在动画就忽略
        guard isMini, !isAnimatingMini else { return }
        expand()
    }

    func setupWindows() {
        // 主窗口
        let mainRect = NSRect(x: 0, y: 0, width: 420, height: 520)
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
        main.minSize = NSSize(width: 400, height: 400)
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

    // A1：主 → 迷你：主窗口 alpha + frame 同步 morph 至 miniPanel restFrame 再切过去
    func hideToMini() {
        guard !isMini, !isAnimatingMini else { return }
        isMini = true
        isAnimatingMini = true

        let main = mainWindow!
        // Bug #2：在任何 morph 动画**之前**保存主窗口原 frame（expand 时还原）
        let currentMainFrame = main.frame
        if currentMainFrame.width >= 200 && currentMainFrame.height >= 200 {
            savedMainFrame = currentMainFrame
        }

        // 计算休息态的 miniPanel rest frame
        let screen = main.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let vf = screen?.visibleFrame else {
            main.orderOut(nil)
            showMiniPanel()
            isAnimatingMini = false
            return
        }
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

        // 用快照替换 contentView，避免 morph 期间 SwiftUI 实时重排造成内容挤压闪烁
        let originalContentView = main.contentView
        let snapshotView = snapshotContentView(of: main)
        if let snapshotView { main.contentView = snapshotView }

        // 先置透明再设 frame/orderFront，避免迷你条此前可见时闪一帧
        miniPanel.alphaValue = 0
        miniPanel.setFrame(snap.restFrame, display: true)
        miniPanel.orderFrontRegardless()

        // 主窗口收缩到 restFrame 中心位置
        let morph = morphFrame(from: currentMainFrame, to: snap.restFrame)
        main.level = .floating
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
            main.animator().setFrame(morph, display: true)
            main.animator().alphaValue = 0.0
            miniPanel.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            main.orderOut(nil)
            // 还原 frame 到原始尺寸 + contentView，使下一次 expand 可直接在完整尺寸快照，
            // 避免 SwiftUI 从 56×220 重新布局到 420×520 的额外延迟。
            if let saved = savedMainFrame { main.setFrame(saved, display: false) }
            main.contentView = originalContentView
            main.alphaValue = 1.0
            main.level = self.isPinned ? .floating : .normal
            self.isAnimatingMini = false
        })
    }

    // A1：迷你 → 主：miniPanel 放大到主窗口原位 + alpha crossfade
    func expand() {
        guard !isAnimatingMini else { return }
        if isMini {
            isAnimatingMini = true
            isPeeking = false
            let main = mainWindow!
            // 直接用迷你条当前实际 frame 作为 morph 起点，避免 snap 缓存值与实际位置错位
            let fromMini = miniPanel.frame

            // 还原 savedMainFrame；若尺寸异常则回退默认
            var desired = savedMainFrame ?? main.frame
            if desired.width < 200 || desired.height < 200 {
                desired = NSRect(x: 0, y: 0, width: 420, height: 520)
                main.setFrame(desired, display: false)
                main.center()
                desired = main.frame
                savedMainFrame = desired
            }

            // 先把主窗口置于目标尺寸（display:true 强制更新 backing store），
            // alpha=0 后 orderFront，让 SwiftUI 完成完整布局再快照；最后缩到 morph 起点。
            // alpha 在 orderFront 之前已置 0，完整尺寸窗口不会被看到。
            main.setFrame(desired, display: true)
            main.alphaValue = 0
            main.orderFront(nil)
            let originalContentView = main.contentView
            if let snapshotView = snapshotContentView(of: main) {
                main.contentView = snapshotView
            }
            let morphStart = morphFrame(from: desired, to: fromMini)
            // 缩到 morph 起点后再 activate，避免激活时闪一帧完整尺寸窗口
            main.setFrame(morphStart, display: false)
            NSApp.activate(ignoringOtherApps: true)

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
                main.animator().setFrame(desired, display: true)
                main.animator().alphaValue = 1.0
                miniPanel.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.miniPanel.orderOut(nil)
                self.miniPanel.alphaValue = 1.0
                main.contentView = originalContentView
                self.isMini = false
                self.isAnimatingMini = false
            })
        } else {
            // 非迷你态展开：刷新 savedMainFrame
            let f = mainWindow.frame
            if f.width >= 200 && f.height >= 200 { savedMainFrame = f }
            mainWindow.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 全局快捷键触发：主窗口可见则隐藏为 mini，否则展开。
    func toggleExpand() {
        if mainWindow.isVisible && !isMini {
            hideToMini()
        } else {
            expand()
        }
    }

    /// 把 fromFrame 收缩/扩展至与 toFrame 相同的中心点和大小，用于窗口 morph。
    private func morphFrame(from: CGRect, to: CGRect) -> CGRect {
        let size = to.size
        let cx = to.midX
        let cy = to.midY
        return CGRect(x: cx - size.width / 2,
                      y: cy - size.height / 2,
                      width: size.width,
                      height: size.height)
    }

    /// 对窗口 contentView 截图，返回一个填充窗口的 NSImageView（图像随窗口缩放）。
    /// morph 期间用快照替换 SwiftUI contentView，避免实时重排导致内容挤压闪烁。
    /// 优先用 dataWithPDF（对 SwiftUI NSHostingView 最可靠），失败时回退 layer.render。
    /// 调用前需确保窗口已 orderFront 或 display，图层才有内容。
    private func snapshotContentView(of window: NSWindow) -> NSImageView? {
        guard let contentView = window.contentView else { return nil }
        let bounds = contentView.bounds
        guard !bounds.isEmpty else { return nil }
        contentView.wantsLayer = true
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        contentView.displayIfNeeded()

        let image: NSImage
        // dataWithPDF 对任意 NSView（含 SwiftUI NSHostingView）都能完整捕获内容
        let pdfData = contentView.dataWithPDF(inside: bounds)
        if let pdfImage = NSImage(data: pdfData) {
            image = pdfImage
        } else if let layer = contentView.layer {
            // 兜底：直接渲染图层树
            let layerImage = NSImage(size: bounds.size)
            layerImage.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                layer.render(in: ctx)
            }
            layerImage.unlockFocus()
            image = layerImage
        } else {
            return nil
        }

        let imageView = NSImageView(image: image)
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        return imageView
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
        // Bug #1 防抖：动画进行中/对齐canonical中不再触发peek（防止反复抽动）
        guard isMini, !isPeeking, !isAnimatingMini, !isAligningCanonical, let snap = lastSnap else { return }
        isPeeking = true
        animatePeek(snap.peekFrame)
    }

    func peekOut() {
        guard isMini, isPeeking, !isAnimatingMini, !isAligningCanonical, let snap = lastSnap else { return }
        isPeeking = false
        animatePeek(snap.restFrame)
    }

    func beginDrag() { isDraggingMini = true }
    func endDrag() { isDraggingMini = false }

    /// 拖动结束后吸附到休息态；若光标仍在条上则 peek。
    func settleMini() {
        guard isMini else { return }
        snapMiniToEdge(animate: true, isSettle: true)
        let mouseLoc = NSEvent.mouseLocation
        if miniPanel.frame.contains(mouseLoc) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                self?.peekIn()
            }
        }
    }

    /// 依据当前面板 frame 计算最近边缘并吸附到休息态。
    func snapMiniToEdge(animate: Bool) {
        snapMiniToEdge(animate: animate, isSettle: false)
    }

    private func snapMiniToEdge(animate: Bool, isSettle: Bool) {
        guard isMini,
              let screen = miniPanel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let frame = miniPanel.frame
        let snap: SnapResult
        if let result = EdgeSnapService.snap(forWindowFrame: frame, visibleFrame: vf,
                                             restWidth: miniSize.width) {
            snap = result
        } else {
            let edge: MiniEdge = frame.midX < vf.midX ? .left : .right
            snap = EdgeSnapService.frames(for: edge, y: frame.minY, visibleFrame: vf,
                                          height: frame.height, restWidth: miniSize.width)
        }
        lastSnap = snap
        let canonical = isPeeking ? snap.peekFrame : snap.restFrame
        if animate {
            animateSnap(canonical, settleBounce: isSettle)
        } else {
            miniPanel.setFrame(canonical, display: true)
        }
    }

    // A5：吸附到边缘用 spring 式 timing + 结束时阴影极短暂脉冲
    private func animateSnap(_ target: CGRect, settleBounce: Bool) {
        isAnimatingMini = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = settleBounce ? 0.42 : 0.24
            if settleBounce {
                // 轻弹簧感：先加速、微超、回到规范位
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.2, 0.36, 1.0)
            } else {
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
            }
            self.miniPanel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimatingMini = false
            self.isAligningCanonical = true
            defer { self.isAligningCanonical = false }
            if let snap = self.lastSnap {
                let canonical = self.isPeeking ? snap.peekFrame : snap.restFrame
                let current = self.miniPanel.frame
                // 仅当偏差显著才对齐（避免浮点抖动触发多次重定位→windowDidMove→snap 重入）
                if abs(current.minX - canonical.minX) > 0.5 || abs(current.minY - canonical.minY) > 0.5
                    || abs(current.width - canonical.width) > 0.5 || abs(current.height - canonical.height) > 0.5 {
                    self.miniPanel.setFrame(canonical, display: true)
                }
            }
            if settleBounce { self.pulseShadow(on: self.miniPanel) }
        })
    }

    /// Peek 动画：宽度变化更线性但仍保持弹性。
    private func animatePeek(_ target: CGRect) {
        isAnimatingMini = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
            self.miniPanel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isAnimatingMini = false
            self.isAligningCanonical = true
            defer { self.isAligningCanonical = false }
            if let snap = self.lastSnap {
                let canonical = self.isPeeking ? snap.peekFrame : snap.restFrame
                let current = self.miniPanel.frame
                if abs(current.minX - canonical.minX) > 0.5 || abs(current.minY - canonical.minY) > 0.5
                    || abs(current.width - canonical.width) > 0.5 || abs(current.height - canonical.height) > 0.5 {
                    self.miniPanel.setFrame(canonical, display: true)
                }
            }
        })
    }

    @available(*, deprecated, message: "use animateSnap / animatePeek instead")
    private func animateFrame(_ target: CGRect) { animatePeek(target) }

    /// A5：吸附到位后的「轻弹闪光」——极短暂加重阴影再回落。
    private func pulseShadow(on window: NSWindow?) {
        guard let window = window else { return }
        let originalHasShadow = window.hasShadow
        window.hasShadow = true
        // 设置阴影变化（setShadowHalo 不可用 → 通过临时透明/恢复来做）
        let a: CGFloat = window.alphaValue
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.06
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = max(0.6, a - 0.15)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = a
            }, completionHandler: {
                window.hasShadow = originalHasShadow
            })
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
