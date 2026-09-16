import SwiftUI

/// 迷你悬浮条视图（纯展示）。事件由宿主 MiniContainerView 处理（拖动/点击），
/// 悬停窥视由 WindowCoordinator 控制面板 frame（rest 56 / peek 180）。
/// 布局策略：
///   - rest（窄）：纵向堆叠 — 顶 DragBar · Icon · 最近便签色卡 · 计数胶囊
///   - peek（宽）：左栏沿用 rest 堆叠；右侧 1 栏显示最近便签标题 + 标签
struct MiniBarView: View {
    @Environment(NoteStore.self) private var store
    private let restBreakpoint: CGFloat = 100

    /// 「最近便签」= 按 updatedAt 降序（最新在前），与 store 的置顶优先排序解耦，
    /// 否则置顶便签会永远占据 mini 窗口，新增便签永远不出现。
    private var recentNotes: [Note] {
        store.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// peek 栏列表顺序：置顶便签优先，组内按 updatedAt 降序；
    /// 列表可滚动，置顶之外的其余便签（含新增）通过下滑查看。
    private var peekNotes: [Note] {
        store.notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    /// 色卡去重源：按颜色去重后的最近便签（一条 = 一个唯一颜色，取该颜色最近更新的便签）。
    /// 同色多条只显示一个点，避免色点重复、点击无法区分。
    private var swatchNotes: [Note] {
        var seen = Set<String>()
        var result: [Note] = []
        for note in recentNotes {
            if seen.insert(note.colorHex).inserted {
                result.append(note)
            }
        }
        return result
    }

    /// 某颜色下的全部便签（updatedAt 降序），供色点右键菜单选择复制
    private func notesWithColor(_ hex: String) -> [Note] {
        store.notes
            .filter { $0.colorHex == hex }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// F5+UI：已复制成功 flash 的便签 ID（nil 表示没有正在 flash）
    @State private var flashedNoteID: UUID? = nil

    var body: some View {
        GeometryReader { geo in
            let isPeek = geo.size.width >= restBreakpoint
            if isPeek {
                peekLayout(flashedID: $flashedNoteID)
            } else {
                restLayout()
                    .onTapGesture { postSidebarTap() }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - rest（56px）：纵向布局
    @ViewBuilder
    private func restLayout() -> some View {
        VStack(spacing: 0) {
            dragBar
                .padding(.top, 8)
                .padding(.bottom, 6)
            Image(systemName: "note.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)
            recentSwatches(maxCount: 4)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            Spacer(minLength: 4)
            countBadge
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle()) // 保证整列（含空白）可被点击
    }

    // MARK: - peek（180px）：左列 + 右栏标题
    @ViewBuilder
    private func peekLayout(flashedID: Binding<UUID?>) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 左列：与 rest 相同的小部件（保持视觉一致，便于 rest→peek 无感）
            // 左列被点击 → 当作侧边栏 → expand()
            VStack(spacing: 0) {
                dragBar
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                Image(systemName: "note.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
                    .padding(.bottom, 8)
                recentSwatches(maxCount: 3)
                    .padding(.horizontal, 10)
                Spacer(minLength: 4)
                countBadge
                    .padding(.bottom, 10)
            }
            .frame(width: 56)
            .contentShape(Rectangle())
            .onTapGesture { postSidebarTap() }

            // 分隔线
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)
                .allowsHitTesting(false)

            // 右栏：便签列表（置顶优先 + 最近更新；可滚动查看全部）
            //   每条：色点 + 标题（1 行） + 标签/内容预览单行 + pin/lock/time
            //   分隔：0.5 细分割线
            VStack(alignment: .leading, spacing: 0) {
                if store.notes.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                        Text("还没有便签")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("主窗口新建第一条吧")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(peekNotes.indices, id: \.self) { idx in
                                let note = peekNotes[idx]
                                let isFlashing = flashedID.wrappedValue == note.id
                                MiniPeekNoteRow(note: note, isFlashing: isFlashing)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        quickCopy(note, flashedID: flashedID)
                                    }
                                if idx < peekNotes.count - 1 {
                                    Divider().opacity(0.35).padding(.leading, 20)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - 共用小部件

    /// 顶部 drag bar：两个圆点 + 中等透明度，给用户明确的可拖动暗示
    private var dragBar: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.primary.opacity(0.35)).frame(width: 4, height: 4)
            Circle().fill(Color.primary.opacity(0.35)).frame(width: 4, height: 4)
        }
        .padding(.vertical, 4)
        .accessibilityLabel(AppStrings.A11y.dragBar)
    }

    private var countBadge: some View {
        Text("\(store.notes.count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.tint.opacity(0.2))
                    .overlay(Capsule().stroke(.tint.opacity(0.4), lineWidth: 0.5))
            )
    }

    /// 最近便签色卡（单列垂直堆叠）。空态显示占位。
    /// 色点按「颜色」去重：一个颜色一个点（取该颜色最近更新的便签）；
    /// 点击 → 快速复制该色最近一条；右键 → 该颜色全部便签菜单。
    @ViewBuilder
    private func recentSwatches(maxCount: Int) -> some View {
        let swatches = Array(swatchNotes.prefix(maxCount))
        if swatches.isEmpty {
            // 空态占位小点
            HStack(spacing: 4) {
                Circle().fill(Color.primary.opacity(0.10)).frame(width: 10, height: 10)
                Circle().fill(Color.primary.opacity(0.08)).frame(width: 8, height: 8)
            }
        } else {
            VStack(spacing: 5) {
                ForEach(swatches, id: \.id) { note in
                    MiniSwatchDot(
                        note: note,
                        allNotes: notesWithColor(note.colorHex),
                        flashedNoteID: $flashedNoteID,
                        onQuickCopy: { quickCopy($0, flashedID: $flashedNoteID) }
                    )
                }
                // 占位使 rest 态有 4 点均匀感
                ForEach(0..<max(0, maxCount - swatches.count), id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 14, height: 14)
                        .opacity(0.3)
                }
            }
        }
    }

    // MARK: - MiniBar tap actions（peek 行点击复制；侧边点击 expand）

    /// peek 态点击某条便签：快速复制内容 → 系统剪贴板；同时触发 copied flash 动画
    private func quickCopy(_ note: Note, flashedID: Binding<UUID?>) {
        let text = note.content.isEmpty ? note.title : note.content
        ClipboardService.copy(text, noteID: note.id, noteTitle: note.title)
        // UI：先设置 flash
        flashedID.wrappedValue = note.id
        // 0.9s 后自动清掉 flash（为了避免连续点击抖动，用一个 DispatchWork，新的点击覆盖老的）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak store] in
            // 如果 flashedID 还是 note.id（没有被另一次点击覆盖），则清空
            if flashedID.wrappedValue == note.id {
                flashedID.wrappedValue = nil
            }
            // 防止 store 被未使用警告
            _ = store
        }
    }

    /// rest 态 / peek 左栏（侧边区域）被点击：发通知，WindowCoordinator 监听后 expand()
    /// 用 NotificationCenter 跨 AppKit/SwiftUI 边界传信，避免闭包穿透多层
    private func postSidebarTap() {
        NotificationCenter.default.post(name: .miniBarSidebarTapped, object: nil)
    }
}

/// 迷你条色卡圆点：一个颜色一个点。
/// 点击 → 快速复制该颜色最近一条便签；右键 → 该颜色全部便签菜单选择复制。
/// flash 时外圈绿色高亮 + 轻微放大；hover 显示细描边提示可点击。
private struct MiniSwatchDot: View {
    let note: Note                    // 该颜色最近更新的便签（点击复制目标）
    let allNotes: [Note]              // 该颜色全部便签（右键菜单）
    @Binding var flashedNoteID: UUID?
    var onQuickCopy: (Note) -> Void

    @State private var isHovered = false

    var body: some View {
        let theme = NoteColorTheme(fromHex: note.colorHex)
        let isFlashing = flashedNoteID == note.id
        Circle()
            .fill(theme.swatch)
            .overlay(Circle().stroke(theme.swatchStroke, lineWidth: 0.5))
            .overlay(
                Circle().stroke(
                    isFlashing ? Color.green : (isHovered ? Color.primary.opacity(0.3) : .clear),
                    lineWidth: isFlashing ? 1.8 : (isHovered ? 1.2 : 0)
                )
            )
            .frame(width: 14, height: 14)
            .overlay(alignment: .topTrailing) {
                if note.isPinned {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                        .padding(.top, -1)
                        .padding(.trailing, -1)
                }
            }
            .scaleEffect(isFlashing ? 1.18 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isFlashing)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .onTapGesture { onQuickCopy(note) }
            .accessibilityLabel("\(AppStrings.A11y.swatchCopy)：\(note.title.isEmpty ? AppStrings.MiniBar.untitled : note.title)")
            .contextMenu {
                // 该颜色全部便签（updatedAt 降序，第一条即最近），点选复制对应内容
                ForEach(allNotes, id: \.id) { n in
                    Button {
                        onQuickCopy(n)
                    } label: {
                        Label(n.title.isEmpty ? "无标题" : n.title,
                              systemImage: "doc.on.clipboard")
                    }
                }
            }
    }
}

/// 通知名：MiniBarView 中侧边区域被点击 → WindowCoordinator 执行 expand
extension Notification.Name {
    static let miniBarSidebarTapped = Notification.Name("CopyNote.miniBarSidebarTapped")
}

/// 迷你 peek 态里的每条便签行：色点 + 标题（1 行） + 标签/内容单行预览 + pin/lock/time
/// isFlashing=true：被点击复制刚成功，显示高亮、bounce、右端"✓ 已复制"滑入
private struct MiniPeekNoteRow: View {
    let note: Note
    var isFlashing: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // 色点：10 色卡
            let theme = NoteColorTheme(fromHex: note.colorHex)
            Circle()
                .fill(theme.swatch)
                .overlay(Circle().stroke(theme.swatchStroke, lineWidth: 0.5))
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                // 标题（不显示时间 / 收藏 / 锁定标记）
                HStack(alignment: .center, spacing: 4) {
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }

                // 正文：有标签 → 前 3 个标签 chip；无标签 → 内容单行首段截断（最多 90 字 + 省略号）
                if !note.tags.isEmpty {
                    CompactTagLine(tags: note.tags)
                } else {
                    Text(contentPreviewOneLine(note.content))
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isFlashing ? Color.green.opacity(0.16) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: isFlashing)
        )
        .overlay(
            // 复制成功 toast："✓ 已复制" — 从右端滑入、淡入淡出
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                Text("已复制")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.green)
                    .shadow(color: Color.green.opacity(0.35), radius: 3, x: 0, y: 1)
            )
            .padding(.trailing, 2)
            .opacity(isFlashing ? 1 : 0)
            .offset(x: isFlashing ? 0 : 14)
            .animation(.spring(response: 0.28, dampingFraction: 0.8).delay(isFlashing ? 0.03 : 0),
                       value: isFlashing),
            alignment: .trailing
        )
        .scaleEffect(isFlashing ? 1.0 : 1.0) // placeholder
        .modifier(CopyFlashBounce(isActive: isFlashing))
    }
}

/// flash 激活时做一次 micro-bounce（scale 0.985 → 1.015 → 1），不干扰行内其他动画
private struct CopyFlashBounce: ViewModifier {
    let isActive: Bool
    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.015 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: pulse)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // 立即轻微缩一下（0.985）再弹回 1.015 再回落 1
                    withAnimation(.easeOut(duration: 0.05)) {
                        pulse = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                        withAnimation {
                            pulse = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            withAnimation {
                                pulse = false
                            }
                        }
                    }
                } else {
                    pulse = false
                }
            }
    }
}

/// 便签行内单行紧凑标签（最多前 3 个 +N，不下垂折行）
private struct CompactTagLine: View {
    let tags: [String]

    var body: some View {
        let visible = Array(tags.prefix(3))
        let extras = max(0, tags.count - 3)
        HStack(spacing: 3) {
            ForEach(visible, id: \.self) { t in
                Text("#\(t)")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .lineLimit(1)
            }
            if extras > 0 {
                Text("+\(extras)")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.04)))
            }
        }
    }
}

/// 内容单行预览（供 MiniPeekNoteRow 使用）：首段非空行 → 去换行空白 → 90 字后省略号
private func contentPreviewOneLine(_ content: String) -> String {
    let firstLine = content
        .split(whereSeparator: { $0.isNewline })
        .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        .map(String.init)
        ?? content
    let oneLiner = firstLine.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if oneLiner.isEmpty { return "（内容为空）" }
    let limit = 90
    if oneLiner.count <= limit { return oneLiner }
    let idx = oneLiner.index(oneLiner.startIndex, offsetBy: limit)
    return String(oneLiner[..<idx]) + "…"
}

/// Smart 时间（MiniPeekNoteRow 调用）：今天 HH:mm / 本周 E HH:mm / 其他 MM-dd
private func miniDate(_ date: Date) -> String {
    let now = Date()
    let cal = Calendar.current
    if cal.isDateInToday(date) {
        let df = DateFormatter(); df.dateFormat = "HH:mm"; return df.string(from: date)
    } else if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
        let df = DateFormatter(); df.dateFormat = "E HH:mm"; df.locale = Locale(identifier: "zh_CN")
        return df.string(from: date)
    } else {
        let df = DateFormatter(); df.dateFormat = "MM-dd"; return df.string(from: date)
    }
}

// MARK: - Wrapping Tag Chips（peek 态内多行折行标签）

/// 简单两行标签容器：第 1 行尽量放，第 2 行放剩余的，最后补 "+N"（当超过 limit 时）。
/// 限制最多展示 limit 个真实标签 + 1 个 +N；防止 GeometryReader 测宽引起类型检查爆炸。
private struct WrappingTagChips: View {
    let tags: [String]
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            rowView(range: 0..<splitIndex)
            if splitIndex < visibleTags.count || extrasCount > 0 {
                rowView(range: splitIndex..<visibleTags.count, plusN: extrasCount > 0 ? extrasCount : nil)
            }
        }
        .frame(minHeight: 30, maxHeight: 58, alignment: .topLeading)
    }

    private var visibleTags: [String] { Array(tags.prefix(limit)) }
    private var extrasCount: Int { max(0, tags.count - limit) }

    /// 第 1 行最多放 3 个，避免过挤；第 2 行放剩余 + 可选 +N
    private var splitIndex: Int {
        min(3, visibleTags.count)
    }

    private func rowView(range: Range<Int>, plusN: Int? = nil) -> some View {
        HStack(spacing: 4) {
            ForEach(visibleTags[range], id: \.self) { tag in
                chipView(text: "#\(tag)", isPlus: false)
            }
            if let n = plusN {
                chipView(text: "+\(n)", isPlus: true)
            }
        }
    }

    private func chipView(text: String, isPlus: Bool) -> some View {
        Group {
            if isPlus {
                Text(text)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else {
                Text(text)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.78))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(isPlus ? Color.primary.opacity(0.04) : Color.primary.opacity(0.07))
        )
    }
}

