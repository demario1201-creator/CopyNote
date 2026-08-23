import SwiftUI

/// 迷你悬浮条视图（纯展示）。事件由宿主 MiniContainerView 处理（拖动/点击），
/// 悬停窥视由 WindowCoordinator 控制面板 frame。
struct MiniBarView: View {
    @Environment(NoteStore.self) private var store

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("\(store.notes.count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.tint.opacity(0.2), in: Capsule())
            if let last = store.notes.first {
                Text(last.title.isEmpty ? "无标题" : last.title)
                    .font(.system(size: 9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
