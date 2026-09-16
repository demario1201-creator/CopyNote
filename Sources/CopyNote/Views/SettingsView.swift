import SwiftUI
import AppKit
import Observation

/// 设置主面板：齿轮图标点击后打开
/// TabView：快捷键 / 语言 / 自动备份 / 关于
struct SettingsView: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            HotkeySettingsView()
                .tabItem {
                    Label(AppStrings.Settings.hotkey, systemImage: "keyboard")
                }

            LanguageSettingsView()
                .tabItem {
                    Label(AppStrings.Settings.language, systemImage: "globe")
                }

            BackupSettingsView()
                .tabItem {
                    Label(AppStrings.Settings.backup, systemImage: "externaldrive.badge.checkmark")
                }

            AboutSettingsView()
                .tabItem {
                    Label(AppStrings.Settings.about, systemImage: "info.circle")
                }
        }
        .frame(minWidth: 560, minHeight: 480)
    }
}

// MARK: - 语言切换设置

private struct LanguageSettingsView: View {
    @State private var lang = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                langOption("system", AppStrings.Settings.systemDefault, "gearshape")
                langOption("zh", AppStrings.Settings.chinese, "character")
                langOption("en", AppStrings.Settings.english, "e.square")
            }
            Spacer()
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(AppStrings.Settings.languageHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label(AppStrings.Settings.language, systemImage: "globe")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
    }

    private func langOption(_ key: String, _ title: String, _ icon: String) -> some View {
        Button {
            lang.preference = key
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .foregroundStyle(lang.preference == key ? Color.accentColor : .secondary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if lang.preference == key {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lang.preference == key ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(lang.preference == key ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08),
                            lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 自动备份设置

private struct BackupSettingsView: View {
    @Environment(NoteStore.self) private var store
    @State private var backups: [(url: URL, date: Date, size: Int64)] = []
    @State private var manualBackupResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            backupLocationSection
            Divider()
            backupListSection
            Spacer(minLength: 0)
        }
        .padding(0)
        .onAppear { refreshBackups() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(AppStrings.Settings.backup, systemImage: "externaldrive.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
            Text(AppStrings.Settings.autoBackupDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: 备份位置

    private var backupLocationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppStrings.Settings.backupLocation)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { openInFinder() } label: {
                    Label(AppStrings.Settings.openInFinder, systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Text(store.backupDirectoryURL.path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.04))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: 备份列表

    private var backupListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppStrings.Settings.backupList)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button { backupNow() } label: {
                    Label(AppStrings.Settings.backupNow, systemImage: "plus.circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if backups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(AppStrings.Settings.noBackups)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(backups.indices, id: \.self) { idx in
                            backupRow(backups[idx])
                            if idx < backups.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            if let msg = manualBackupResult {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func backupRow(_ item: (url: URL, date: Date, size: Int64)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor.opacity(0.7))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(formatDate(item.date))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(formatSize(item.size))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                restoreBackup(item.url)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(AppStrings.Settings.restore)

            Button {
                deleteBackup(item.url)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(AppStrings.Settings.deleteBackup)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { openInFinder() }
    }

    // MARK: Actions

    private func refreshBackups() {
        backups = store.backupFiles()
    }

    private func backupNow() {
        if store.createBackupNow() != nil {
            manualBackupResult = AppStrings.Backup.backupCreated
            refreshBackups()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { manualBackupResult = nil }
            }
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([store.backupDirectoryURL])
    }

    private func restoreBackup(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = AppStrings.Settings.restore
        alert.informativeText = AppStrings.Settings.restoreConfirm
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppStrings.Settings.restore)
        alert.addButton(withTitle: AppStrings.Delete.cancel)
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { resp in
                if resp == .alertFirstButtonReturn {
                    if let data = try? Data(contentsOf: url),
                       let notes = try? JSONDecoder().decode([Note].self, from: data) {
                        store.replaceNotes(notes)
                        refreshBackups()
                    }
                }
            }
        }
    }

    private func deleteBackup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        refreshBackups()
    }

    // MARK: Format

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            f.dateFormat = "HH:mm:ss"
            return AppStrings.Settings.date + ": \(f.string(from: date))"
        }
        if cal.isDateInYesterday(date) {
            f.dateFormat = "HH:mm"
            return "昨天 \(f.string(from: date))"
        }
        f.locale = LanguageManager.shared.isChinese
            ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let b = Double(bytes)
        if b < 1024 { return "\(Int(b)) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
        return String(format: "%.1f MB", b / (1024 * 1024))
    }
}

// MARK: - 关于

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App 图标：新版图标自带 squircle 底板（PNG 透明背景）。
            // 放大 + 圆角裁剪，裁掉图标四周的透明留白，避免露出底板色
            Image(nsImage: AppIconFactory.makeAppIcon())
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            VStack(spacing: 4) {
                Text("CopyNote")
                    .font(.system(size: 20, weight: .bold))
                Text(AppStrings.Settings.appDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text(AppStrings.Settings.version)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("1.6.0")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(0.06)))

            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "swift")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("SwiftUI + AppKit · SwiftPM")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text("© 2026 CopyNote · MIT License")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }

            Divider()
                .frame(width: 240)

            // 开发者信息
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("demario1201-creator")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Link("github.com/demario1201-creator/CopyNote",
                         destination: URL(string: "https://github.com/demario1201-creator/CopyNote")!)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()
                .frame(width: 200)

            // 重启 / 退出 按钮
            HStack(spacing: 12) {
                Button { restartApp() } label: {
                    Label(AppStrings.Settings.restartApp, systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(role: .destructive) { quitApp() } label: {
                    Label(AppStrings.Settings.quitApp, systemImage: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restartApp() {
        let alert = NSAlert()
        alert.messageText = AppStrings.Settings.restartApp
        alert.informativeText = AppStrings.Settings.restartConfirm
        alert.addButton(withTitle: AppStrings.Settings.restartApp)
        alert.addButton(withTitle: AppStrings.Delete.cancel)
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { resp in
                if resp == .alertFirstButtonReturn {
                    let url = URL(fileURLWithPath: Bundle.main.bundlePath)
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func quitApp() {
        let alert = NSAlert()
        alert.messageText = AppStrings.Settings.quitApp
        alert.informativeText = AppStrings.Settings.quitConfirm
        alert.addButton(withTitle: AppStrings.Settings.quitApp)
        alert.addButton(withTitle: AppStrings.Delete.cancel)
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { resp in
                if resp == .alertFirstButtonReturn {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
