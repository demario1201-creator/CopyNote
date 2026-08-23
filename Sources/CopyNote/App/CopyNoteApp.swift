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
            Button("显示主窗口") { appDelegate.coordinator.expand() }
            Button("隐藏为悬浮条") { appDelegate.coordinator.hideToMini() }
            Divider()
            Button("导入便签 JSON") {
                let _ = ImportExportService.importNotes(store: appDelegate.store)
            }
            Button("导出全部便签") {
                ImportExportService.exportAll(appDelegate.store.notes)
            }
            Divider()
            Button("退出 CopyNote", role: .destructive) {
                NSApp.terminate(nil)
            }
        } label: {
            // 自定义 StatusBar 图标（纯代码绘制，18×18 模板图）
            Label {
                Text("CopyNote")
            } icon: {
                statusBarImage
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
