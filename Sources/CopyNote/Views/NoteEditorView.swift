import SwiftUI

/// 便签编辑器：标题 + 内容 + 标签；实时回写 store。
struct NoteEditorView: View {
    @Binding var note: Note
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newTagText = ""

    var body: some View {
        VStack(spacing: 12) {
            TextField("标题", text: $note.title)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
            tagsSection
            TextEditor(text: $note.content)
                .font(.body)
                .frame(minHeight: 160)
                .padding(4)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380, height: 420)
        .onChange(of: note) { _, newNote in
            store.update(newNote)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("添加标签，回车确认", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !note.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption.weight(.medium))
                            Button {
                                note.tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(.tint.opacity(0.25), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func addTag() {
        let text = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !note.tags.contains(text) else {
            newTagText = ""
            return
        }
        note.tags.append(text)
        newTagText = ""
    }
}

/// 简易流式布局容器。
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

