import SwiftUI
import AppKit
import Carbon.HIToolbox

/// 快捷键设置面板：列出所有 action，支持录制新快捷键 + 冲突检测
struct HotkeySettingsView: View {
    @State private var config = HotkeyConfigStore.shared
    @State private var recordingAction: HotkeyAction?
    @State private var conflictMessages: [String: String] = [:] // action.rawValue → 冲突描述
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(HotkeyAction.allCases) { action in
                        row(action)
                        if action != HotkeyAction.allCases.last {
                            Divider()
                                .padding(.leading, 160)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 460)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label(AppStrings.Hotkey.title, systemImage: "keyboard")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(HotkeyAction.allCases.filter { $0.isGlobal }.count) \(AppStrings.Hotkey.global) · \(HotkeyAction.allCases.filter { !$0.isGlobal }.count) \(AppStrings.Hotkey.inApp)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ action: HotkeyAction) -> some View {
        let binding = config.binding(for: action)
        let isRecording = recordingAction == action
        let conflictText = conflictMessages[action.rawValue]

        HStack(spacing: 12) {
            // 左：图标 + 名称 + 类型标签
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: action.isGlobal ? "globe" : "app")
                        .font(.system(size: 10))
                        .foregroundStyle(action.isGlobal ? .blue : .secondary)
                    Text(action.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(action.isGlobal ? AppStrings.Hotkey.global : AppStrings.Hotkey.inApp)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
            Spacer(minLength: 8)

            // 中：快捷键显示/录制区
            if isRecording {
                HStack(spacing: 4) {
                    Image(systemName: "circle.badge.record")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text(AppStrings.Hotkey.recording)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.08))
                        .stroke(Color.red.opacity(0.25), lineWidth: 0.5)
                )
                .overlay(
                    KeyCaptureView(
                        onCancel: { stopRecording() },
                        onCapture: { keyEvent in
                            applyRecording(action: action, event: keyEvent)
                        }
                    )
                    .opacity(0)
                )
            } else {
                HStack(spacing: 2) {
                    ForEach(displaySymbols(binding), id: \.self) { sym in
                        Text(sym)
                            .font(.system(size: 12, weight: .medium))
                            .frame(minWidth: 18, minHeight: 20)
                            .padding(.horizontal, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.07))
                                    .shadow(color: .black.opacity(0.06), radius: 0.5, y: 0.5)
                            )
                    }
                }
                .foregroundStyle(conflictText != nil ? Color.red : .primary)
            }

            // 右：录制/重置 按钮
            if isRecording {
                Button(AppStrings.Hotkey.stop) { stopRecording() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button(AppStrings.Hotkey.record) { startRecording(action) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button {
                    resetAction(action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppStrings.Hotkey.reset)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(conflictText != nil
                      ? Color.red.opacity(0.06)
                      : (recordingAction == action ? Color.accentColor.opacity(0.06) : Color.clear))
        )
        .overlay(alignment: .bottomLeading) {
            if let conflictText {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                    Text(conflictText)
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRecording { startRecording(action) }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(AppStrings.Hotkey.resetAll, role: .destructive) {
                config.resetAll()
                conflictMessages.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
            Button(AppStrings.Hotkey.close) { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func startRecording(_ action: HotkeyAction) {
        recordingAction = action
        conflictMessages[action.rawValue] = nil
    }

    private func stopRecording() {
        recordingAction = nil
    }

    private func resetAction(_ action: HotkeyAction) {
        config.reset(action)
        conflictMessages[action.rawValue] = nil
    }

    private func applyRecording(action: HotkeyAction, event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = UInt32(event.keyCode)

        // 允许 Escape 取消
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        // 必须至少有一个修饰键（除了 Delete/Backspace 这种特殊键）
        let isSpecialKey = keyCode == UInt32(kVK_Delete) || keyCode == UInt32(kVK_ForwardDelete)
        if !isSpecialKey && modifiers.isEmpty {
            // 不允许无修饰键的普通字母键
            conflictMessages[action.rawValue] = AppStrings.Hotkey.conflict
            stopRecording()
            return
        }

        let binding = HotkeyBinding(action: action, keyCode: keyCode, modifiers: modifiers)
        let conflict = config.setBinding(binding)

        if let conflictAction = conflict {
            conflictMessages[action.rawValue] =
                "\(AppStrings.Hotkey.conflictWith)\(conflictAction.displayName)」"
        } else {
            conflictMessages[action.rawValue] = nil
        }

        stopRecording()

        // 全局热键变更后通知 AppDelegate 重新注册
        if action.isGlobal {
            NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
        }
    }

    // MARK: - Display helpers

    /// 把 binding 的 displayString 拆成单个符号数组，每个符号一个 key cap
    private func displaySymbols(_ binding: HotkeyBinding) -> [String] {
        var parts: [String] = []
        if binding.modifiers.contains(.control) { parts.append("⌃") }
        if binding.modifiers.contains(.option)  { parts.append("⌥") }
        if binding.modifiers.contains(.shift)   { parts.append("⇧") }
        if binding.modifiers.contains(.command)   { parts.append("⌘") }
        parts.append(HotkeyBinding.keyName(for: binding.keyCode))
        return parts
    }
}

/// 透明 NSEvent 捕获层：拦截第一个 keyDown 事件
private struct KeyCaptureView: NSViewRepresentable {
    let onCancel: () -> Void
    let onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onCancel = onCancel
        view.onCapture = onCapture
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCaptureNSView: NSView {
    var onCancel: (() -> Void)?
    var onCapture: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onCapture?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        // 如果用户按 Escape
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
        }
    }
}

extension Notification.Name {
    static let hotkeyConfigChanged = Notification.Name("CopyNote.hotkeyConfigChanged")
}
