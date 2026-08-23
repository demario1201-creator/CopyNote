import SwiftUI

/// 单条便签行：单击复制内容；提供编辑/删除。
/// `compact=true` 时仅显示单行标题，垂直紧凑排布。
struct NoteRowView: View {
    let note: Note
    var compact: Bool = false
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var copied = false
    @State private var hovered = false

    private var copyText: String {
        note.content.isEmpty ? note.title : note.content
    }

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                fullBody
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in hovered = hovering }
        .onTapGesture {
            ClipboardService.copy(copyText)
            withAnimation(.easeOut(duration: 0.15)) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeInOut(duration: 0.3)) { copied = false }
            }
        }
    }

    // MARK: - Full（展开模式）

    private var fullBody: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "无标题" : note.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.content.isEmpty ? "（空）" : note.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(note.tags.prefix(3)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9).weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        if note.tags.count > 3 {
                            Text("+\(note.tags.count - 3)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("编辑")
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除")
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .scaleEffect(copied ? 1.15 : 1.0)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Compact（折叠模式）

    private var compactBody: some View {
        HStack(spacing: 8) {
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                .font(.system(size: 11))
                .foregroundStyle(copied ? .green : .secondary)
                .scaleEffect(copied ? 1.1 : 1.0)
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            if !note.content.isEmpty {
                Text("·")
                    .font(.system(size: 11))
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
                    .font(.system(size: 9).weight(.medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                if note.tags.count > 1 {
                    Text("+\(note.tags.count - 1)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Text(note.updatedAt, format: .dateTime.month().day())
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            if hovered {
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("编辑")
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("删除")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: hovered)
    }
}
