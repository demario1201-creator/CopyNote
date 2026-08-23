import SwiftUI
import AppKit

/// 主窗口根视图：工具栏（新建/置顶/排序/隐藏为悬浮条）+ 搜索 + 便签列表。
/// F3：星标/锁定；F5：选择 + 键盘快捷键（⌘E 编辑 / ⌫ 删除 / ⌘D 复制 / ⌘↵ 复制内容）。
struct MainNoteListView: View {
    @Environment(NoteStore.self) private var store
    @State private var searchText = ""
    @State private var editingNote = Note(title: "", content: "")
    @State private var isEditing = false
    @State private var isPinned = false
    @State private var selectedTag: String? = nil
    @State private var isCompact = false
    @AppStorage("copynote.isCompact") private var isCompactPersisted = false
    // F5：选中的便签 ID（支持键盘操作）
    @State private var selection: Note.ID?

    var onTogglePin: () -> Void
    var onHide: () -> Void

    private var displayed: [Note] {
        let base = store.filter(byTag: selectedTag)
        let terms = searchText.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return base }
        return base.filter { note in
            terms.allSatisfy { term in
                note.title.localizedCaseInsensitiveContains(term)
                    || note.content.localizedCaseInsensitiveContains(term)
                    || note.tags.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
    }

    private var selectedNote: Note? {
        guard let id = selection else { return nil }
        return store.notes.first { $0.id == id }
    }

    private var tagAllBgColor: Color {
        selectedTag == nil
            ? Color(nsColor: NSColor.controlAccentColor)
            : Color(nsColor: NSColor.systemGray)
    }
    private var tagAllBorderColor: Color {
        selectedTag == nil
            ? Color(nsColor: NSColor.controlAccentColor)
            : Color(nsColor: NSColor.systemGray)
    }

    var body: some View {
        Group {
            mainBodyView
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $isEditing) {
            NoteEditorView(note: $editingNote)
        }
        .onAppear { isCompact = isCompactPersisted }
        .onChange(of: isCompact) { _, value in
            withAnimation(.easeInOut(duration: 0.25)) { isCompactPersisted = value }
        }
        .background(
            WindowShortcutBridge(onEdit: keyEditSelected,
                                  onDuplicate: keyDuplicateSelected,
                                  onCopyContent: { _ = keyCopySelectedContent() },
                                  onDelete: { _ = keyDeleteSelected() })
                .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private var mainBodyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            if displayed.isEmpty {
                emptyLayoutView
            } else {
                listContentView
            }
        }
    }

    @ViewBuilder
    private var emptyLayoutView: some View {
        SearchBar(text: $searchText).padding(10)
        if !store.allTags.isEmpty {
            tagFilterBar
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
        emptyState
    }

    @ViewBuilder
    private var listContentView: some View {
        List(selection: $selection) {
            listSectionContent
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .focusable()
    }

    @ViewBuilder
    private var listSectionContent: some View {
        Section {
            ForEach(displayed, id: \.id, content: rowContent)
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                SearchBar(text: $searchText)
                if !store.allTags.isEmpty { tagFilterBar }
            }
            .padding(.top, 2)
            .padding(.bottom, 4)
            .textCase(.none)
        }
    }

    @ViewBuilder
    private func rowContent(_ note: Note) -> some View {
        NoteRowView(note: note,
                    compact: isCompact,
                    onEdit: { edit(note) },
                    onRequestDelete: { requestDelete(note) },
                    onTogglePinned: { store.togglePinned(note) },
                    onToggleLocked: { store.toggleLocked(note) })
            .contextMenu { rowContextMenu(note) }
            .tag(note.id)
            .transition(rowTransition)
    }

    private var rowTransition: AnyTransition {
        .asymmetric(
            insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.8)),
            removal: .opacity.combined(with: .move(edge: .leading)))
    }

    @ViewBuilder
    private func rowContextMenu(_ note: Note) -> some View {
        Section {
            Button("编辑 ⌘E") { edit(note) }
            Button { _ = requestDelete(note) } label: {
                Label(note.isLocked ? "删除（锁定，将确认）" : "删除",
                      systemImage: note.isLocked ? "trash.slash" : "trash")
            }
            Button { store.duplicate(note) } label: {
                Label("复制副本 ⌘D", systemImage: "plus.square.on.square")
            }
            Button { copyContent(note) } label: {
                Label("复制内容 ⌘↵", systemImage: "doc.on.doc")
            }
        }
        Divider()
        Section {
            Button { store.togglePinned(note) } label: {
                Label(note.isPinned ? "取消星标" : "加为星标",
                      systemImage: note.isPinned ? "pin.slash" : "pin.fill")
            }
            Button { store.toggleLocked(note) } label: {
                Label(note.isLocked ? "解除锁定" : "锁定便签",
                      systemImage: note.isLocked ? "lock.open" : "lock.fill")
            }
        }
        Divider()
        Section {
            Button { ImportExportService.exportSingle(note) } label: {
                Label("导出此便签", systemImage: "square.and.arrow.up")
            }
            Menu("添加标签") {
                ForEach(store.allTags, id: \.self) { tag in
                    Button(tag) { withAnimation { store.addTag(tag, to: note) } }
                        .disabled(note.tags.contains(tag))
                }
            }
            Menu("移除标签") {
                ForEach(note.tags, id: \.self) { tag in
                    Button("#\(tag)") { withAnimation { store.removeTag(tag, from: note) } }
                }
            }
        }
    }

    // MARK: - F5 键盘处理

    private func keyEditSelected() {
        guard let n = selectedNote else { return }
        edit(n)
    }

    private func keyDuplicateSelected() {
        guard let n = selectedNote else { return }
        let copy = store.duplicate(n)
        selection = copy.id
    }

    private func keyCopySelectedContent() -> KeyPress.Result {
        guard let n = selectedNote else { return .ignored }
        copyContent(n)
        return .handled
    }

    private func keyDeleteSelected() -> KeyPress.Result {
        guard let n = selectedNote else { return .ignored }
        if requestDelete(n) { return .handled }
        return .handled
    }

    // MARK: - 复制（带选中反馈）

    private func copyContent(_ note: Note) {
        let text = note.content.isEmpty ? note.title : note.content
        ClipboardService.copy(text)
        // 临时把 selection 触发一次视觉反馈（NoteRowView 已经有内部动画）
        selection = note.id
    }

    // MARK: - 删除（带锁定确认）

    @discardableResult
    private func requestDelete(_ note: Note) -> Bool {
        if note.isLocked {
            // F3：锁定便签 → 显示 NSAlert 二次确认
            let alert = NSAlert()
            alert.messageText = "删除已锁定的便签"
            alert.informativeText = "「\(note.title.isEmpty ? "无标题" : note.title)」已锁定，确定要删除吗？此操作不可撤销。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "删除")
            alert.addButton(withTitle: "取消")
            if let window = NSApp.keyWindow {
                alert.beginSheetModal(for: window) { resp in
                    if resp == .alertFirstButtonReturn {
                        withAnimation(.easeInOut(duration: 0.25)) { store.delete(note) }
                        if selection == note.id { selection = nil }
                    }
                }
                return true
            } else {
                if alert.runModal() == .alertFirstButtonReturn {
                    withAnimation(.easeInOut(duration: 0.25)) { store.delete(note) }
                    if selection == note.id { selection = nil }
                    return true
                }
                return false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { store.delete(note) }
            if selection == note.id { selection = nil }
            return true
        }
    }

    // MARK: - 标签筛选条

    private var tagFilterBar: some View {
        let accent = Color(nsColor: NSColor.controlAccentColor)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HoverableTagCapsule(bgColor: tagAllBgColor,
                                    borderColor: tagAllBorderColor,
                                    selected: selectedTag == nil) {
                    Label("全部", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.medium))
                } onClick: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTag = nil }
                }
                ForEach(store.allTags, id: \.self) { tag in
                    HoverableTagCapsule(bgColor: accent,
                                        borderColor: accent,
                                        selected: selectedTag == tag) {
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                    } onClick: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTag = (selectedTag == tag) ? nil : tag
                        }
                    }
                }
            }
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 4) {
            Image(nsImage: AppIconFactory.makeStatusBarImage(length: 16))
            Text("CopyNote")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary.opacity(0.85))
                .layoutPriority(1)
            Spacer(minLength: 4)
            ToolbarHoverButton(title: "新建便签 ⌘N", systemImage: "plus", action: newNote)
            Menu {
                Button { ImportExportService.exportAll(store.notes) } label: {
                    Label("导出全部便签", systemImage: "square.and.arrow.up")
                }
                Button { let _ = ImportExportService.importNotes(store: store) } label: {
                    Label("导入便签 JSON", systemImage: "square.and.arrow.down")
                }
            } label: {
                ToolbarHoverButtonLabel(systemImage: "square.and.arrow.up.on.square", title: "导入/导出便签 JSON")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            Menu {
                Picker("排序", selection: Binding(
                    get: { store.sortOrder },
                    set: { newValue in withAnimation(.easeInOut(duration: 0.3)) { store.setSortOrder(newValue) } }
                )) {
                    ForEach(NoteStore.SortOrder.allCases) { order in
                        Label(order.rawValue, systemImage: order.symbol).tag(order)
                    }
                }
                .labelsHidden()
            } label: {
                ToolbarHoverButtonLabel(systemImage: "arrow.up.arrow.down", title: "排序：单击切换 / 长按展开")
            } primaryAction: {
                let cases = NoteStore.SortOrder.allCases
                if let i = cases.firstIndex(of: store.sortOrder) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.setSortOrder(cases[(i + 1) % cases.count])
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)

            HoverableToolbarToggle(isOn: $isCompact,
                                   onTitle: "展开显示",
                                   offTitle: "紧凑显示",
                                   onImage: "rectangle.compress.vertical",
                                   offImage: "rectangle.expand.vertical")

            HoverableToolbarToggle(isOn: $isPinned,
                                   onTitle: "取消置顶",
                                   offTitle: "窗口置顶",
                                   onImage: "pin.fill",
                                   offImage: "pin",
                                   onChange: onTogglePin)

            ToolbarHoverButton(title: "隐藏为悬浮条 ⌥⌘N",
                               systemImage: "sidebar.right",
                               action: onHide)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - 空状态（U6 插画）

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 64))
                    .foregroundStyle(.tertiary)
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color(nsColor: NSColor.controlAccentColor), .white)
                    .offset(x: 6, y: -6)
            }
            .padding(.bottom, 4)

            VStack(spacing: 4) {
                Text(searchText.isEmpty ? "还没有便签" : "无匹配结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if searchText.isEmpty {
                    Text("点击下方按钮创建你的第一条便签，或使用 ⌥⌘N 随时呼出。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }

            if searchText.isEmpty {
                Button { newNote() } label: {
                    Label("新建便签", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 便签操作（带动画 A2）

    private func newNote() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            editingNote = store.add()
            selection = editingNote.id
        }
        isEditing = true
    }

    private func edit(_ note: Note) {
        editingNote = note
        isEditing = true
    }
}

// MARK: - F5 键盘快捷键 —— 本地 NSEvent 监视器

private struct WindowShortcutBridge: NSViewRepresentable {
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onCopyContent: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let window = view.window, window.isKeyWindow else { return event }
                let cmd = event.modifierFlags.contains(.command)
                // ⌘↵：复制选中便签内容
                if cmd, event.keyCode == 36 /* Return */ { onCopyContent(); return nil }
                // Delete / Backspace：删除选中便签（无 cmd 也生效）
                switch event.keyCode {
                case 51 /* Backspace */, 117 /* Forward Delete (Del) */:
                    onDelete(); return nil
                default: break
                }
                guard cmd else { return event }
                let ch = event.charactersIgnoringModifiers
                if ch == "e" { onEdit(); return nil }
                if ch == "d" { onDuplicate(); return nil }
                return event
            }
            objc_setAssociatedObject(view, &monitorKey, monitor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let m = objc_getAssociatedObject(nsView, &monitorKey) {
            NSEvent.removeMonitor(m)
        }
    }
}
private var monitorKey: UInt8 = 0

// MARK: - 工具栏按钮共用组件（A4 hover 微交互）

private struct ToolbarHoverButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(hovered ? Color.accentColor.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(hovered ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .scaleEffect(hovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovered = h } }
    }
}

private struct ToolbarHoverButtonLabel: View {
    let systemImage: String
    let title: String
    @State private var hovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13))
            .frame(width: 28, height: 28)
            .background(hovered ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(hovered ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 0.5)
            )
            .scaleEffect(hovered ? 1.05 : 1)
            .help(title)
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovered = h } }
    }
}

private struct HoverableToolbarToggle: View {
    @Binding var isOn: Bool
    let onTitle: String
    let offTitle: String
    let onImage: String
    let offImage: String
    var onChange: (() -> Void)?
    @State private var hovered = false

    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: isOn ? onImage : offImage)
                .font(.system(size: 13))
                .foregroundStyle(isOn ? Color.accentColor : .primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn ? Color.accentColor.opacity(0.15) : (hovered ? Color.accentColor.opacity(0.08) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isOn ? Color.accentColor.opacity(0.3) : (hovered ? Color.accentColor.opacity(0.2) : Color.clear), lineWidth: 0.5)
                )
                .scaleEffect(hovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .help(isOn ? onTitle : offTitle)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovered = h } }
        .onChange(of: isOn) { _, _ in onChange?() }
    }
}

// MARK: - 标签胶囊共用组件（A4 hover + U3 视觉统一）

private struct HoverableTagCapsule<Content: View>: View {
    let bgColor: Color
    let borderColor: Color
    let selected: Bool
    @ViewBuilder let content: () -> Content
    let onClick: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onClick) {
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        selected ? bgColor.opacity(0.25) : (hovered ? bgColor.opacity(0.14) : bgColor.opacity(0.08))
                    )
                )
                .overlay(
                    Capsule()
                        .stroke((selected ? borderColor : borderColor.opacity(0.6)).opacity(hovered ? 0.4 : 0.3),
                                lineWidth: 1)
                )
                .scaleEffect(hovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { hovered = h } }
    }
}
