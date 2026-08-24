import SwiftUI
import AppKit

/// 主窗口根视图：工具栏（新建/置顶/排序/隐藏为悬浮条）+ 搜索 + 便签列表。
/// F3：星标/锁定；F5：选择 + 键盘快捷键（⌘E 编辑 / ⌫ 删除 / ⌘D 复制 / ⌘↵ 复制内容）。
/// F4：复制历史（工具栏 Popover）；F6：分组视图（按首个标签 DisclosureGroup + 未分类）。
/// A6：紧凑↔展开切换动画（withAnimation + asymmetric row transition）。
struct MainNoteListView: View {
    @Environment(NoteStore.self) private var store
    @State private var searchText = ""
    @State private var editingNote = Note(title: "", content: "")
    @State private var isEditing = false
    @State private var isPinned = false
    @State private var selectedTag: String? = nil

    // A6：compact/full 过渡（持久化到 AppStorage，切换加动画）
    @State private var isCompact = false
    @AppStorage("copynote.isCompact") private var isCompactPersisted = false

    // F5：选中的便签 ID（支持键盘操作）
    @State private var selection: Note.ID?

    // F4：复制历史 Popover 开关 + 本地 mirror 跟随 ClipboardHistoryStore.shared.items
    @State private var showHistory = false
    @State private var historyItems: [ClipboardHistoryItem] = []

    // F6：分组视图开关（按标签分组 + 未分类）
    @State private var isGrouped = false
    @AppStorage("copynote.isGrouped") private var isGroupedPersisted = false

    var onTogglePin: () -> Void
    var onHide: () -> Void

    // MARK: - 显示数据

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

    // MARK: - F6 分组数据

    /// 分组 key：如果 note.tags 非空，取第一个标签；否则归入 "" → "未分类"
    private struct NoteTagGroup: Identifiable, Hashable {
        var id: String { key }
        let key: String       // 标签名；"" 表示未分类
        let title: String     // 展示名
        let notes: [Note]
    }

    private var groups: [NoteTagGroup] {
        // 按首个标签分组；保持分组顺序：按 allTags 顺序 + "未分类" 放最后
        let grouped = Dictionary(grouping: displayed) { note -> String in
            note.tags.first ?? ""
        }
        var result: [NoteTagGroup] = []
        // 先按 store.allTags 顺序推进所有"有标签组"
        for tag in store.allTags {
            guard let notes = grouped[tag], !notes.isEmpty else { continue }
            result.append(NoteTagGroup(key: tag, title: "#\(tag)", notes: notes))
        }
        // 最后未分类（如存在）
        if let uncategorized = grouped[""], !uncategorized.isEmpty {
            result.append(NoteTagGroup(key: "", title: "未分类", notes: uncategorized))
        }
        return result
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

    // MARK: - Root

    var body: some View {
        Group {
            mainBodyView
        }
        .frame(minWidth: 320, minHeight: 400)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $isEditing) {
            NoteEditorView(note: $editingNote)
        }
        .onAppear {
            isCompact = isCompactPersisted
            isGrouped = isGroupedPersisted
            refreshHistory()
        }
        // A6：compact/full 切换带动画；持久化写回
        .onChange(of: isCompact) { _, newValue in
            withAnimation(.easeInOut(duration: 0.25)) { isCompactPersisted = newValue }
        }
        // F6：分组切换持久化
        .onChange(of: isGrouped) { _, newValue in
            withAnimation(.easeInOut(duration: 0.25)) { isGroupedPersisted = newValue }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardHistoryChanged)) { _ in
            refreshHistory()
        }
        .background(
            WindowShortcutBridge(onEdit: keyEditSelected,
                                  onDuplicate: keyDuplicateSelected,
                                  onCopyContent: { _ = keyCopySelectedContent() },
                                  onDelete: { _ = keyDeleteSelected() },
                                  onToggleHistory: { withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() } })
                .frame(width: 0, height: 0)
        )
    }

    private func refreshHistory() {
        historyItems = ClipboardHistoryStore.shared.items
    }

    // MARK: - Body 分块

    @ViewBuilder
    private var mainBodyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            if displayed.isEmpty {
                emptyLayoutView
            } else if isGrouped {
                groupedContentView
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
            listHeaderView
        }
    }

    /// F6：分组视图 — 按「首个标签」DisclosureGroup；最后一组是未分类
    @ViewBuilder
    private var groupedContentView: some View {
        List(selection: $selection) {
            Section {
                ForEach(groups) { g in
                    DisclosureGroup {
                        ForEach(g.notes, id: \.id, content: rowContent)
                    } label: {
                        HStack(spacing: 6) {
                            if g.key.isEmpty {
                                Label(g.title, systemImage: "tray")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Label {
                                    Text(g.title)
                                        .font(.system(size: 12, weight: .semibold))
                                } icon: {
                                    Image(systemName: "number")
                                        .foregroundStyle(Color(nsColor: NSColor.controlAccentColor))
                                }
                            }
                            Text("\(g.notes.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.primary.opacity(0.06))
                                )
                            Spacer()
                            // 本组星标数提示（可选）
                            let pinCount = g.notes.filter(\.isPinned).count
                            if pinCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(.orange)
                                    Text("\(pinCount)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                listHeaderView
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .focusable()
    }

    @ViewBuilder
    private var listHeaderView: some View {
        VStack(alignment: .leading, spacing: 6) {
            SearchBar(text: $searchText)
            if !store.allTags.isEmpty { tagFilterBar }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
        .textCase(.none)
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

    // MARK: - A6：行 transition

    private var rowTransition: AnyTransition {
        .asymmetric(
            insertion:
                    .scale.combined(with: .opacity)
                    .combined(with: .move(edge: .top))
                    .animation(.spring(response: 0.35, dampingFraction: 0.82)),
            removal:
                    .opacity
                    .combined(with: .move(edge: .leading))
                    .animation(.easeInOut(duration: 0.22))
        )
    }

    // MARK: - 右键菜单

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
                Label(note.isPinned ? "取消收藏" : "收藏",
                      systemImage: note.isPinned ? "star.fill" : "star")
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
        ClipboardService.copy(text, noteID: note.id, noteTitle: note.title)
        // 临时把 selection 触发一次视觉反馈（NoteRowView 已经有内部动画）
        selection = note.id
        // 历史刷新（Popover 如果开着会同步显示最新一条）
        refreshHistory()
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

            // F4：复制历史 Popover 入口（⌘⇧V）
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ToolbarHoverButtonStyle())
            .help("复制历史 ⌘⇧V")
            .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                ClipboardHistoryPopover(items: $historyItems,
                                        onRecopy: { item in
                                            ClipboardHistoryStore.shared.recopy(item)
                                            refreshHistory()
                                        },
                                        onClear: {
                                            ClipboardHistoryStore.shared.removeAll()
                                            refreshHistory()
                                        },
                                        onRefresh: refreshHistory)
            }

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

            // F6：分组视图开关（按标签分组）
            HoverableToolbarToggle(isOn: $isGrouped,
                                   onTitle: "取消分组（扁平列表）",
                                   offTitle: "按标签分组视图",
                                   onImage: "list.bullet.indent",
                                   offImage: "folder")

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

// MARK: - 工具栏按钮共用 style（给 F4 Popover 按钮复用 hover 效果）

private struct ToolbarHoverButtonStyle: ButtonStyle {
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                (hovered ? Color.accentColor.opacity(0.12) : Color.clear),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke((hovered ? Color.accentColor.opacity(0.25) : Color.clear), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .scaleEffect(hovered && !configuration.isPressed ? 1.05 : (configuration.isPressed ? 0.97 : 1))
            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovered = h } }
    }
}

// MARK: - F5 键盘快捷键 —— 本地 NSEvent 监视器

private struct WindowShortcutBridge: NSViewRepresentable {
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onCopyContent: () -> Void
    let onDelete: () -> Void
    let onToggleHistory: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let window = view.window, window.isKeyWindow else { return event }
                let cmd = event.modifierFlags.contains(.command)
                let shift = event.modifierFlags.contains(.shift)
                // ⌘↵：复制选中便签内容
                if cmd, event.keyCode == 36 /* Return */ { onCopyContent(); return nil }
                // Delete / Backspace：删除选中便签（无 cmd 也生效）
                switch event.keyCode {
                case 51 /* Backspace */, 117 /* Forward Delete (Del) */:
                    onDelete(); return nil
                default: break
                }
                // F4：⌘⇧V 打开复制历史
                if cmd && shift {
                    if event.charactersIgnoringModifiers == "v" { onToggleHistory(); return nil }
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

// MARK: - F4 复制历史 Popover

private struct ClipboardHistoryPopover: View {
    @Binding var items: [ClipboardHistoryItem]
    var onRecopy: (ClipboardHistoryItem) -> Void
    var onClear: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if items.isEmpty {
                emptyTip
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items.indices, id: \.self) { idx in
                            let item = items[idx]
                            ClipboardHistoryRow(item: item, onRecopy: { onRecopy(item) })
                            if idx < items.count - 1 {
                                Divider().opacity(0.4).padding(.leading, 38)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minWidth: 360, minHeight: 240, idealHeight: 360)
            }
        }
        .frame(width: 380)
        .onAppear { onRefresh() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Label("复制历史（最多 10 条）", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))
            Spacer(minLength: 0)
            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("刷新")
            Button {
                onClear()
            } label: {
                Label("清空", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(items.isEmpty ? Color.secondary.opacity(0.55) : Color.red.opacity(0.85))
            }
            .buttonStyle(.borderless)
            .disabled(items.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var emptyTip: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("复制历史是空的")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("在主窗口或迷你条复制一次便签内容即可入史")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    var onRecopy: () -> Void
    @State private var hovered = false
    @State private var flashCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 左侧序号 + 圆形
            let indexColor = Color(nsColor: NSColor.controlAccentColor)
            ZStack {
                Circle()
                    .fill(indexColor.opacity(0.12))
                    .frame(width: 22, height: 22)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(indexColor)
            }
            .padding(.top, 4)

            // 内容：标题（若有）+ 内容 2 行预览；最右下时间
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.noteTitle.isEmpty ? "（无标题便签）" : item.noteTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if item.contentSnapshot.isEmpty {
                        Text("空")
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Text(Self.timeFormat(item.copiedAt))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }

                Text(Self.preview(item.contentSnapshot))
                    .font(.system(size: 11))
                    .lineLimit(2, reservesSpace: false)
                    .truncationMode(.tail)
                    .foregroundStyle(.secondary)
            }

            // 右侧：点击 "再次复制" 按钮
            Button {
                onRecopy()
                flash()
            } label: {
                Label {
                    Text(flashCopied ? "已复制" : "复制")
                        .font(.system(size: 10, weight: .semibold))
                } icon: {
                    Image(systemName: flashCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(flashCopied ? .green : Color(nsColor: NSColor.controlAccentColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color(nsColor: NSColor.controlAccentColor).opacity(0.09))
                )
            }
            .buttonStyle(.plain)
            .help("再次复制这条内容 ⌘ 点击列表任意处也可复制")
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(flashCopied ? Color.green.opacity(0.14) : (hovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .animation(.easeInOut(duration: 0.18), value: flashCopied)
        .contentShape(Rectangle())
        .onTapGesture {
            onRecopy()
            flash()
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.14)) { hovered = h } }
    }

    private func flash() {
        withAnimation(.easeInOut(duration: 0.18)) {
            flashCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.2)) { flashCopied = false }
        }
    }

    private static func preview(_ text: String) -> String {
        let s = text
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "（内容为空）" }
        if s.count > 180 {
            let i = s.index(s.startIndex, offsetBy: 180)
            return String(s[..<i]) + "…"
        }
        return s
    }

    private static let timeFmt: DateFormatter = {
        let d = DateFormatter()
        d.locale = Locale(identifier: "zh_CN")
        d.dateFormat = "HH:mm"
        return d
    }()

    private static func timeFormat(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return timeFmt.string(from: date) }
        if cal.isDateInYesterday(date) { return "昨天 " + timeFmt.string(from: date) }
        let comps = cal.dateComponents([.day], from: date, to: Date())
        if let d = comps.day, d >= 2 && d < 7 { return "\(d)天前" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "MM-dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - F4 通知：ClipboardHistory 变更 → 主视图刷新 Popover
extension Notification.Name {
    static let clipboardHistoryChanged = Notification.Name("CopyNote.clipboardHistoryChanged")
}

/// 让 ClipboardHistoryStore 在 items 变化后广播通知（供 MainNoteListView 同步）
@MainActor
private extension ClipboardHistoryStore {
    nonisolated static let swizzleOnce: Void = {
        // Swift 5.9 / no method swizzle；改为用 didSet-like 包装。下面通过 MainActor 扩展直接 hook 所有 setter。
    }()
}

/// 将 ClipboardHistoryStore 的变更广播（为了 @Observable + SwiftUI onReceive 能收到）。
/// 在 ClipboardService 成功 push/recopy/removeAll/remove 后均 post：
@MainActor
private enum ClipboardHistoryNotify {
    static func emit() {
        NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
    }
}
