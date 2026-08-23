import SwiftUI

/// 主窗口根视图：工具栏（新建/置顶/排序/隐藏为悬浮条）+ 搜索 + 便签列表。
struct MainNoteListView: View {
    @Environment(NoteStore.self) private var store
    @State private var searchText = ""
    @State private var editingNote = Note(title: "", content: "")
    @State private var isEditing = false
    @State private var isPinned = false
    @State private var showSortMenu = false
    @State private var selectedTag: String? = nil
    @State private var isCompact = false
    @AppStorage("copynote.isCompact") private var isCompactPersisted = false

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
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()
            if displayed.isEmpty {
                SearchBar(text: $searchText).padding(10)
                if !store.allTags.isEmpty {
                    tagFilterBar
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                }
                Divider()
                emptyState
            } else {
                List {
                    Section {
                        ForEach(displayed) { note in
                            NoteRowView(note: note,
                                        compact: isCompact,
                                        onEdit: { edit(note) },
                                        onDelete: { store.delete(note) })
                                .contextMenu {
                                    Button("编辑") { edit(note) }
                                    Button {
                                        ImportExportService.exportSingle(note)
                                    } label: {
                                        Label("导出此便签", systemImage: "square.and.arrow.up")
                                    }
                                    Menu("添加标签") {
                                        ForEach(store.allTags, id: \.self) { tag in
                                            Button(tag) { store.addTag(tag, to: note) }
                                                .disabled(note.tags.contains(tag))
                                        }
                                    }
                                    Menu("移除标签") {
                                        ForEach(note.tags, id: \.self) { tag in
                                            Button("#\(tag)") { store.removeTag(tag, from: note) }
                                        }
                                    }
                                    Divider()
                                    Button("删除", role: .destructive) { store.delete(note) }
                                }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 6) {
                            SearchBar(text: $searchText)
                            if !store.allTags.isEmpty {
                                tagFilterBar
                            }
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                        .textCase(.none)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 320, minHeight: 400)
        .sheet(isPresented: $isEditing) {
            NoteEditorView(note: $editingNote)
        }
        .onAppear { isCompact = isCompactPersisted }
        .onChange(of: isCompact) { _, value in isCompactPersisted = value }
    }

    private var tagFilterBar: some View {
        let accent = Color(nsColor: NSColor.controlAccentColor)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    selectedTag = nil
                } label: {
                    Label("全部", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tagAllBgColor.opacity(selectedTag == nil ? 0.25 : 0.1),
                                    in: Capsule())
                        .overlay(Capsule().stroke(tagAllBorderColor.opacity(0.3),
                                                   lineWidth: 1))
                }
                .buttonStyle(.plain)
                ForEach(store.allTags, id: \.self) { tag in
                    Button {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    } label: {
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent.opacity(selectedTag == tag ? 0.25 : 0.08),
                                        in: Capsule())
                            .overlay(Capsule().stroke(accent.opacity(0.3),
                                                       lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(nsImage: AppIconFactory.makeStatusBarImage(length: 16))
            Text("CopyNote").font(.headline).lineLimit(1).layoutPriority(1)
            Spacer(minLength: 4)
            Button { newNote() } label: {
                Label("新建", systemImage: "plus").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("新建便签")
            Menu {
                Button {
                    ImportExportService.exportAll(store.notes)
                } label: {
                    Label("导出全部便签", systemImage: "square.and.arrow.up")
                }
                Button {
                    let _ = ImportExportService.importNotes(store: store)
                } label: {
                    Label("导入便签 JSON", systemImage: "square.and.arrow.down")
                }
            } label: {
                Label("导入导出", systemImage: "square.and.arrow.up.on.square").labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
            .help("导入/导出便签 JSON")
            Menu {
                Picker("排序", selection: Binding(
                    get: { store.sortOrder },
                    set: { store.setSortOrder($0) }
                )) {
                    ForEach(NoteStore.SortOrder.allCases) { order in
                        Label(order.rawValue, systemImage: order.symbol).tag(order)
                    }
                }
                .labelsHidden()
            } label: {
                Label("排序", systemImage: "arrow.up.arrow.down").labelStyle(.iconOnly)
            } primaryAction: {
                let cases = NoteStore.SortOrder.allCases
                if let i = cases.firstIndex(of: store.sortOrder) {
                    let next = cases[(i + 1) % cases.count]
                    store.setSortOrder(next)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
            .help("排序：单击切换 / 长按展开")
            Toggle(isOn: $isCompact) {
                Label("紧凑", systemImage: isCompact ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .help(isCompact ? "展开显示" : "紧凑显示")
            Toggle(isOn: $isPinned) {
                Label("置顶", systemImage: "pin").labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .help(isPinned ? "取消置顶" : "窗口置顶")
            .onChange(of: isPinned) { _, _ in onTogglePin() }
            Button { onHide() } label: {
                Label("悬浮", systemImage: "sidebar.right").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("隐藏为悬浮条")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "还没有便签" : "无匹配结果")
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Button("新建便签") { newNote() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func newNote() {
        editingNote = store.add()
        isEditing = true
    }

    private func edit(_ note: Note) {
        editingNote = note
        isEditing = true
    }
}
