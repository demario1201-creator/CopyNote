import SwiftUI
import AppKit

/// 单条便签行：单击复制内容；提供编辑/删除/星标/锁定。
/// `compact=true` 时仅显示单行标题，垂直紧凑排布。
/// 根据 `note.colorHex` 显示颜色主题（左侧色条 + 卡片背景 tint）。
/// `onRequestDelete` 返回 true 表示「用户确认过可以删」或「isLocked=false」，View 层负责锁定确认对话框。
struct NoteRowView: View {
    let note: Note
    var compact: Bool = false
    var onEdit: () -> Void
    var onRequestDelete: () -> Bool   // 返回 true 则实际执行了删除（调用方已 store.delete）
    var onTogglePinned: () -> Void
    var onToggleLocked: () -> Void

    @State private var copied = false
    @State private var hovered = false
    @State private var copiedFlash = false  // A3 脉冲描边

    private var theme: NoteColorTheme { NoteColorTheme(fromHex: note.colorHex) }
    private var copyText: String {
        note.content.isEmpty ? note.title : note.content
    }

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                fullBodyCard
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { hovered = hovering }
        }
        .onTapGesture {
            ClipboardService.copy(copyText, noteID: note.id, noteTitle: note.title)
            triggerCopiedFeedback()
        }
    }

    // MARK: - Full（展开模式）—— 卡片化 + 左侧色条

    private var fullBodyCard: some View {
        HStack(spacing: 0) {
            // F2：左侧竖条颜色指示器
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(theme.swatch)
                .frame(width: 4)
                .padding(.vertical, 4)
                .padding(.leading, 3)
                .opacity(theme == .default ? 0 : 1)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        // F3：收藏按钮 + 锁定指示
                        HStack(spacing: 2) {
                            Button { withAnimation(.easeInOut(duration: 0.15)) { onTogglePinned() } } label: {
                                Image(systemName: note.isPinned ? "star.fill" : "star")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(note.isPinned ? Color.orange : Color.primary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help(note.isPinned ? "取消收藏" : "收藏")
                            .opacity(hovered || note.isPinned ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.15), value: hovered)

                            Button { withAnimation(.easeInOut(duration: 0.15)) { onToggleLocked() } } label: {
                                Image(systemName: note.isLocked ? "lock.fill" : "lock.open")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(note.isLocked ? Color(nsColor: .systemIndigo) : Color.primary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help(note.isLocked ? "解除锁定（删除前将不再确认）" : "锁定（删除前需二次确认）")
                            .opacity(hovered || note.isLocked ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.15), value: hovered)
                        }

                        Text(note.title.isEmpty ? "无标题" : note.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)

                        Spacer(minLength: 6)
                        // 操作按钮：横排在右上，hovered 才淡入
                        HStack(spacing: 2) {
                            copyIndicator
                            Button { onEdit() } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                            .help("编辑")
                            Button {
                                _ = onRequestDelete()
                            } label: {
                                Image(systemName: note.isLocked ? "trash.slash" : "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(note.isLocked ? Color.red.opacity(0.6) : .primary)
                            }
                            .buttonStyle(.borderless)
                            .help(note.isLocked ? "已锁定：删除前将显示确认" : "删除")
                        }
                        .opacity(hovered ? 1 : 0.28)
                        .animation(.easeInOut(duration: 0.15), value: hovered)
                    }
                    // F1：用 AttributedString 渲染内容（Markdown），最多 3 行
                    Text(MarkdownRenderer.renderPreview(note.content, maxLength: 220))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(alignment: .bottom, spacing: 8) {
                        if !note.tags.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(Array(note.tags.prefix(3)), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 8.5, weight: .medium))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.22), lineWidth: 0.5))
                                }
                                if note.tags.count > 3 {
                                    Text("+\(note.tags.count - 3)")
                                        .font(.system(size: 8.5))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer(minLength: 4)
                        Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 8.5))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 8)
            }
            .padding(10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(copied ? Color.green.opacity(0.7) : (copiedFlash ? Color.green.opacity(0.9) : (note.isPinned ? Color.orange.opacity(0.5) : Color.primary.opacity(0.07))),
                            lineWidth: note.isPinned || copied || copiedFlash ? 1.1 : 0.5)
                    .animation(
                        copiedFlash ? .easeOut(duration: 0.12).repeatCount(2, autoreverses: true)
                                   : .easeInOut(duration: 0.2),
                        value: copiedFlash
                    )
            )
        }
        .shadow(color: hovered ? .black.opacity(0.08) : .black.opacity(0.03),
                radius: hovered ? 6 : 2, x: 0, y: hovered ? 2 : 1)
        .scaleEffect(hovered ? 1.008 : 1)
        .animation(.easeInOut(duration: 0.18), value: hovered)
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
    }

    private var cardBackground: some View {
        let copiedTint = Color.green.opacity(0.07)
        let hoveredTint = Color.primary.opacity(0.025)
        let pinnedTint = Color.orange.opacity(0.05)
        let baseFill: Color = theme.cardTint
        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(baseFill)
            if note.isPinned { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(pinnedTint) }
            if copied { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(copiedTint) }
            else if hovered { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hoveredTint) }
        }
    }

    private var copyIndicator: some View {
        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
            .font(.system(size: 11))
            .foregroundStyle(copied ? .green : .secondary)
            .scaleEffect(copied ? 1.2 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: copied)
    }

    // MARK: - Compact（折叠模式）

    private var compactBody: some View {
        HStack(spacing: 5) {
            // F2：左端小圆色色标
            Circle()
                .fill(theme.swatch)
                .frame(width: 6, height: 6)
                .opacity(theme == .default ? 0 : 1)
            // F3：收藏/锁定小图
            Image(systemName: note.isPinned ? "star.fill" : "star")
                .font(.system(size: 8.5))
                .foregroundStyle(note.isPinned ? .orange : .clear.opacity(0))
                .frame(width: 10)
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                .font(.system(size: 10.5))
                .foregroundStyle(copied ? .green : .secondary)
                .scaleEffect(copied ? 1.12 : 1.0)
                .animation(.easeOut(duration: 0.15), value: copied)
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
            if !note.content.isEmpty {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(note.content)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }
            Spacer(minLength: 4)
            if !note.tags.isEmpty {
                Text("#\(note.tags.first ?? "")")
                    .font(.system(size: 8.5, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                if note.tags.count > 1 {
                    Text("+\(note.tags.count - 1)")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                }
            }
            Text(note.updatedAt, format: .dateTime.month().day())
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color(nsColor: .systemIndigo).opacity(0.7))
            }
            if hovered {
                Button { onEdit() } label: {
                    Image(systemName: "pencil").font(.system(size: 9.5))
                }
                .buttonStyle(.borderless)
                .help("编辑")
                Button { _ = onRequestDelete() } label: {
                    Image(systemName: note.isLocked ? "trash.slash" : "trash").font(.system(size: 9.5))
                }
                .buttonStyle(.borderless)
                .help(note.isLocked ? "已锁定：删除前将显示确认" : "删除")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(copied ? Color.green.opacity(0.07) :
                       (hovered ? (theme == .default ? Color.primary.opacity(0.03) : theme.cardTint.opacity(0.8))
                                : theme.cardTint.opacity(0.35)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(copied ? Color.green.opacity(0.6)
                              : (note.isPinned ? Color.orange.opacity(0.45) : Color.clear),
                        lineWidth: note.isPinned || copied ? 1 : 0)
        )
        .scaleEffect(hovered ? 1.006 : 1)
        .animation(.easeInOut(duration: 0.16), value: hovered)
        .padding(.vertical, 1)
    }

    // MARK: - A3 复制反馈（绿色描边脉冲 + 基础）

    private func triggerCopiedFeedback() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
            copied = true
        }
        withAnimation(.easeOut(duration: 0.12).repeatCount(2, autoreverses: true).delay(0.02)) {
            copiedFlash = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    copied = false
                    copiedFlash = false
                }
            }
        }
    }
}
