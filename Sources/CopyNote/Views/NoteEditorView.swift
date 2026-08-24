import SwiftUI
import AppKit

/// 便签编辑器：色卡选择器 + 纸张背景 + 标题/内容 + 标签；实时回写 store。
/// F1：支持 Markdown 预览切换。
struct NoteEditorView: View {
    @Binding var note: Note
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newTagText = ""
    @State private var showPreview = false  // F1：编辑 vs 预览

    private var theme: NoteColorTheme { NoteColorTheme(fromHex: note.colorHex) }
    private var wordCount: Int { note.content.isEmpty ? 0 : note.content.split(whereSeparator: \.isWhitespace).count }
    private var charCount: Int { note.content.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 10) {
                titleField
                colorPickerRow
                contentEditor
                tagsSection
            }
            .padding(14)
            .background(paperBackground)
            Divider().opacity(0.4)
            footer
        }
        .frame(width: 420, height: 520)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 6)
        .onChange(of: note) { _, newNote in
            store.update(newNote)
        }
    }

    // MARK: - 顶部标题栏

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(theme.swatch)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(theme.swatchStroke.opacity(0.8), lineWidth: 1))
            Text("编辑便签")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            // F3：收藏 + 锁定
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { note.isPinned.toggle() }
            } label: {
                Image(systemName: note.isPinned ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(note.isPinned ? .orange : .primary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(note.isPinned ? "取消收藏" : "收藏")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { note.isLocked.toggle() }
            } label: {
                Image(systemName: note.isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundStyle(note.isLocked ? Color(nsColor: .systemIndigo) : .primary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(note.isLocked ? "解除锁定" : "锁定便签（删除前需二次确认）")

            Spacer()

            // F1：Markdown 预览切换
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPreview.toggle() }
            } label: {
                Image(systemName: showPreview ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(showPreview ? Color.accentColor : .primary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
            .help(showPreview ? "返回编辑模式" : "Markdown 预览")

            Text("\(wordCount) 字 · \(charCount) 字符")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 标题输入（无边框）

    private var titleField: some View {
        TextField("便签标题…", text: $note.title)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
    }

    // MARK: - 色卡选择器（F2）

    private var colorPickerRow: some View {
        HStack(spacing: 6) {
            ForEach(NoteColorTheme.allCases) { t in
                Button {
                    note.colorHex = (t == .default) ? "" : t.toHex
                } label: {
                    ZStack {
                        Circle()
                            .fill(t.swatch)
                            .frame(width: 22, height: 22)
                        if theme.id == t.id {
                            Circle()
                                .stroke(t.swatchStroke, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(t == .default ? Color.primary : .white)
                        } else {
                            Circle()
                                .stroke(t.swatchStroke.opacity(0.5), lineWidth: 0.8)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(t.name)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 内容编辑器（F1：编辑 vs Markdown 预览切换）

    private var contentEditor: some View {
        ZStack {
            // 背景纸张（始终保留）
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(colors: [theme.paperPrimary, theme.paperSecondary],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.swatchStroke.opacity(theme == .default ? 0.12 : 0.35),
                                lineWidth: 0.8)
                )
            if showPreview {
                // F1：Markdown 预览
                ScrollView {
                    HStack {
                        Text(MarkdownRenderer.render(note.content))
                            .font(.system(size: 13, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .padding(12)
                }
                .overlay(
                    // 预览模式标签
                    HStack {
                        Spacer()
                        Text("预览")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                            .padding(6)
                    },
                    alignment: .topTrailing
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                // 编辑模式
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note.content)
                        .font(.system(size: 13, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if note.content.isEmpty {
                        Text("开始书写内容…支持换行，Markdown 可选。")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.placeholder)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.01)))
            }
        }
        .frame(minHeight: 190)
        .animation(.easeInOut(duration: 0.2), value: showPreview)
    }

    // MARK: - 标签区（U3：统一胶囊 + 常用标签快速条）

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 常用标签快速点击（最多取 store.allTags 前 6 个未添加的）
            let quickTags = store.allTags.filter { !note.tags.contains($0) }.prefix(6)
            if !quickTags.isEmpty {
                HStack(spacing: 4) {
                    Text("常用:")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    ForEach(quickTags, id: \.self) { tag in
                        Button {
                            if !note.tags.contains(tag) {
                                withAnimation(.easeInOut(duration: 0.15)) { note.tags.append(tag) }
                            }
                        } label: {
                            Text("#\(tag)")
                                .font(.system(size: 9.5, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.08), in: Capsule())
                                .overlay(Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 输入框
            HStack(spacing: 6) {
                TextField("添加标签，回车确认", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit(addTag)
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // 已添加标签（U3：hover 胶囊样式）
            if !note.tags.isEmpty {
                FlowLayout(spacing: 5) {
                    ForEach(note.tags, id: \.self) { tag in
                        TagWithRemove(tag: tag) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                note.tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 底部操作栏

    private var footer: some View {
        HStack {
            Button(role: .cancel) { dismiss() } label: {
                Text("取消")
            }
            .keyboardShortcut(.cancelAction)
            Spacer()
            Button { dismiss() } label: {
                Text("保存")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 纸张背景

    private var paperBackground: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(
                LinearGradient(colors: [
                    theme.paperPrimary.opacity(0.6),
                    theme.paperSecondary.opacity(0.5)
                ], startPoint: .top, endPoint: .bottom)
            )
    }

    // MARK: - 辅助

    private func addTag() {
        let text = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !note.tags.contains(text) else {
            newTagText = ""
            return
        }
        withAnimation(.easeInOut(duration: 0.15)) { note.tags.append(text) }
        newTagText = ""
    }
}

// MARK: - 标签 + 删除按钮（U3 胶囊统一）

private struct TagWithRemove: View {
    let tag: String
    let onRemove: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 3) {
            Text("#\(tag)")
                .font(.system(size: 9.5, weight: .medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(hovered ? 0.9 : 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule().fill(
                Color.accentColor.opacity(hovered ? 0.16 : 0.12)
            )
        )
        .overlay(
            Capsule().stroke(Color.accentColor.opacity(hovered ? 0.32 : 0.24), lineWidth: 0.7)
        )
        .scaleEffect(hovered ? 1.03 : 1)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { hovered = h } }
        .help("移除标签 \(tag)")
    }
}

// MARK: - 简易流式布局容器

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .greatestFiniteMagnitude)
        guard !rows.isEmpty else { return .zero }
        let width = rows.map { row in
            row.reduce(0) { $0 + ($1.size.width + spacing) } - spacing
        }.max() ?? 0
        let height = rows.reduce(0) { $0 + ($1.first?.size.height ?? 0) + spacing } - spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.first?.size.height ?? 0
            for cell in row {
                cell.view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: cell.size.width, height: cell.size.height))
                x += cell.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [[(view: LayoutSubview, size: CGSize)]] {
        var rows: [[(LayoutSubview, CGSize)]] = []
        var current: [(LayoutSubview, CGSize)] = []
        var currentWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if !current.isEmpty && currentWidth + spacing + size.width > width {
                rows.append(current)
                current = []
                currentWidth = 0
            }
            current.append((sub, size))
            currentWidth += (current.count == 1 ? 0 : spacing) + size.width
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}
