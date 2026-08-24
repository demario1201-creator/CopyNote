import AppKit
import SwiftUI

@main
struct CopyNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private var statusBarImage: Image {
        Image(nsImage: AppIconFactory.makeStatusBarImage())
    }

    var body: some Scene {
        MenuBarExtra {
            Button(AppStrings.App.showMainWindow) { appDelegate.coordinator.expand() }
            Button(AppStrings.App.hideToMiniBar) { appDelegate.coordinator.hideToMini() }
            Divider()
            Button(AppStrings.App.hotkeySettings) {
                AppDelegate.shared?.showSettings()
            }
            Divider()
            Button(AppStrings.App.importJSON) {
                let _ = ImportExportService.importNotes(store: appDelegate.store)
            }
            Button(AppStrings.App.exportAll) {
                ImportExportService.exportAll(appDelegate.store.notes)
            }
            Divider()
            Button(AppStrings.App.quit, role: .destructive) {
                NSApp.terminate(nil)
            }
        } label: {
            // 自定义 StatusBar 图标（纯代码绘制，18×18 模板图）
            Label {
                Text(AppStrings.App.name)
            } icon: {
                statusBarImage
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
