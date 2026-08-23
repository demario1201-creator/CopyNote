import AppKit

/// 应用代理：激活策略、窗口协调器、屏幕变化重排。
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NoteStore()
    lazy var coordinator = WindowCoordinator(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 设置 Dock / Finder 自定义 App 图标
        NSApp.applicationIconImage = AppIconFactory.makeAppIcon()

        coordinator.setupWindows()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        // 注册 ⌥⌘N 全局热键：切换主窗口 / 迷你悬浮条
        HotKeyManager.shared.registerToggleKey { [weak self] in
            self?.coordinator.toggleExpand()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func screensChanged() {
        coordinator.reflowOnScreenChange()
    }
}
