import AppKit
import SwiftUI

/// 应用代理：激活策略、窗口协调器、屏幕变化重排。
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let store = NoteStore()
    lazy var coordinator = WindowCoordinator(store: store)

    /// 设置窗口（NSWindow hosting SwiftUI SettingsView）
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

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

        // 快捷键配置变更后重新注册全局热键
        NotificationCenter.default.addObserver(
            self, selector: #selector(hotkeyConfigChanged),
            name: .hotkeyConfigChanged, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    @objc private func hotkeyConfigChanged() {
        // 重新注册全局热键（使用新的配置）
        HotKeyManager.shared.registerToggleKey { [weak self] in
            self?.coordinator.toggleExpand()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func screensChanged() {
        coordinator.reflowOnScreenChange()
    }

    // MARK: - 设置窗口

    /// 打开设置窗口（如果已关闭则创建，如果已打开则置前）
    func showSettings() {
        DispatchQueue.main.async { [weak self] in
            self?.showSettingsWindow()
        }
    }

    @MainActor
    private func showSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environment(store)

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = AppStrings.Settings.title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 580, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
