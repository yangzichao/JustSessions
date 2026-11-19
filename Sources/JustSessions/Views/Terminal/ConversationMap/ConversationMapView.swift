import SwiftUI

struct ConversationMapView: View {
    let model: ConversationOutlineModel
    let conversation: Conversation?
    let provider: ConversationProvider
    let store: ConversationStore
    let hover: ConversationMapHover
    var editor: MessageBookmarkEditorRequests? = nil
    @State private var isWindowVisible = false
    @State private var offsetFromTop: CGFloat?
    @Environment(\.tabBarTerminalPalette) private var terminalPalette
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale

    private struct FollowKey: Equatable {
        let source: String?
        let isOnScreen: Bool
    }

    private var followKey: FollowKey {
        FollowKey(source: conversation.map { $0.id + "|" + $0.sourceFile.path }, isOnScreen: isWindowVisible)
    }

    private var language: AppInterfaceLanguage { AppInterfaceLanguage(identifier: locale.identifier) }

    var body: some View {
        let colors = ConversationMapColors(palette: terminalPalette, provider: provider)
        let bookmarks = conversation.map { store.messageBookmarks.bookmarks(forConversationID: $0.id) } ?? []
        ZStack(alignment: .top) {
            WindowVisibilityReader { isWindowVisible = $0 }
                .accessibilityHidden(true)
            if let conversation, let outline = model.outline, outline.rowCount > 0 {
                drawing(outline, bookmarks: bookmarks, colors: colors, conversation: conversation)
            } else if conversation == nil {
                ConversationMapEmptyState(text: "Not linked yet", color: colors.caption)
            } else if model.outline != nil {
                ConversationMapEmptyState(text: "No messages yet", color: colors.caption)
            } else if model.couldNotRead {
                ConversationMapEmptyState(text: "Could not read this session", color: colors.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: conversation?.id) { offsetFromTop = nil }
        .task(id: followKey, priority: .utility) {
            guard followKey.isOnScreen, let conversation else { return }
            await model.watch(conversation)
        }
    }

    private func drawing(
        _ outline: ConversationOutline, bookmarks: [MessageBookmark], colors: ConversationMapColors,
        conversation: Conversation
    ) -> some View {
        GeometryReader { geometry in
            let chipSide = ConversationMapMetrics.chipSide
            let factor = InterfaceScale.factor
            let layout = ConversationMapLayout(
                rowCount: outline.rowCount, height: geometry.size.height,
                naturalPitch: ConversationMapMetrics.naturalRowPitch,
                verticalInset: ConversationMapMetrics.verticalInset,
                minimumPitch: ConversationMapMetrics.minimumRowPitch,
                offsetFromTop: offsetFromTop)
            let chips = layout.chips(
                for: bookmarks, in: outline, side: chipSide, height: geometry.size.height,
                titles: ConversationMapChipTitles.titles(for: bookmarks, side: chipSide, factor: factor))
            ZStack(alignment: .topLeading) {
                ConversationMapScrollReader(isScrollable: layout.isScrollable) { distance in
                    let current = ConversationMapLayout(
                        rowCount: outline.rowCount, height: geometry.size.height,
                        naturalPitch: ConversationMapMetrics.naturalRowPitch,
                        verticalInset: ConversationMapMetrics.verticalInset,
                        minimumPitch: ConversationMapMetrics.minimumRowPitch,
                        offsetFromTop: offsetFromTop)
                    offsetFromTop = current.offsetFromTop(afterScrollingBy: distance)
                }
                .accessibilityHidden(true)
                ConversationMapHoverBand(hover: hover, color: colors.hoverBand)
                ConversationMapCanvas(
                    outline: outline, layout: layout, chips: chips, colors: colors,
                    pixel: 1 / max(1, displayScale), chipSide: chipSide, letterFont: ThemeFont.caption.weight(.semibold),
                    scrollThumbWidth: ConversationMapMetrics.scrollThumbWidth(at: factor),
                    scrollThumbMinimumLength: ConversationMapMetrics.scrollThumbMinimumLength(at: factor)
                )
                .equatable()
                if let editor {
                    ConversationMapChipMenus(
                        chips: chips, bookmarks: bookmarks, width: geometry.size.width, side: chipSide,
                        onOpen: {
                            hover.hide()
                            open(.bookmark($0), conversation)
                        },
                        onEdit: { editor.open($0, in: conversation) },
                        onRemove: { store.removeMessageBookmark($0, in: conversation) })
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    showCard(at: point, outline: outline, layout: layout, chips: chips, bookmarks: bookmarks, size: geometry.size)
                case .ended:
                    hover.hide()
                }
            }
            .onChange(of: outline.revision) {
                if let point = hover.point {
                    showCard(at: point, outline: outline, layout: layout, chips: chips, bookmarks: bookmarks, size: geometry.size)
                }
            }
            .onChange(of: layout.scrollOffset) {
                if let point = hover.point {
                    showCard(at: point, outline: outline, layout: layout, chips: chips, bookmarks: bookmarks, size: geometry.size)
                }
            }
            // A relink or an emptied session takes the drawing, and its tracking area, without an `.ended`.
            .onDisappear { hover.hide() }
            .onTapGesture(count: 1, coordinateSpace: .local) { point in
                hover.hide()
                if let bookmark = layout.bookmark(at: point, chips: chips, bookmarks: bookmarks, width: geometry.size.width, side: chipSide)
                {
                    open(.bookmark(bookmark), conversation)
                } else if let index = outline.blockIndex(atRow: layout.row(atY: point.y)),
                    let entryID = outline.targetEntryID(forBlockAt: index)
                {
                    open(.entry(entryID), conversation)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Conversation map"))
        .accessibilityValue(
            Text(
                verbatim: ConversationMapAccessibility.value(
                    messageCount: outline.messageCount,
                    bookmarkCount: bookmarks.count, language: language))
        )
        .accessibilityAction(named: Text("Open in reading window")) { open(nil, conversation) }
        .accessibilityActions {
            ForEach(bookmarks, id: \.letter) { bookmark in
                Button("Go to bookmark \(bookmark.letter)") { open(.bookmark(bookmark), conversation) }
                if let editor {
                    Button("Edit bookmark \(bookmark.letter)…") { editor.open(bookmark, in: conversation) }
                }
            }
        }
        .accessibilityIdentifier("terminal.conversation-map")
    }

    private func open(_ navigation: SessionReadingNavigation?, _ conversation: Conversation) {
        SessionReadingWindowManager.shared.open(
            store.conversation(withID: conversation.id) ?? conversation, store: store, navigation: navigation)
    }

    private func showCard(
        at point: CGPoint, outline: ConversationOutline, layout: ConversationMapLayout,
        chips: [ConversationMapLayout.Chip], bookmarks: [MessageBookmark], size: CGSize
    ) {
        let chipBookmark = layout.bookmark(
            at: point, chips: chips, bookmarks: bookmarks, width: size.width,
            side: ConversationMapMetrics.chipSide)
        guard let index = chipBookmark.flatMap(outline.blockIndex(for:)) ?? outline.blockIndex(atRow: layout.row(atY: point.y)) else {
            hover.hide()
            return
        }
        let bookmark = bookmarks.first { outline.blockIndex(for: $0) == index }
        guard
            index != hover.card?.blockIndex || outline.revision != hover.card?.revision
                || bookmark?.letter != hover.card?.letter || bookmark?.label != hover.card?.label || bookmark?.tags != hover.card?.tags
        else { return }
        let block = outline.blocks[index]
        let speaker =
            switch block.kind {
            case .user, .image: AppLocalization.string("You", language: language)
            case .assistant: provider.rawValue
            case .toolRun:
                block.toolCallCount == 1
                    ? AppLocalization.string("1 tool call", language: language)
                    : AppLocalization.string("\(block.toolCallCount) tool calls", language: language)
            }
        let rowY = layout.y(ofRow: outline.rowStarts[index])
        hover.show(
            ConversationMapHover.Card(
                blockIndex: index,
                revision: outline.revision,
                speaker: speaker,
                timestamp: block.timestamp,
                snippet: block.kind == .image ? AppLocalization.string("Image", language: language) : block.snippet,
                letter: bookmark?.letter,
                label: bookmark?.label,
                tags: bookmark?.tags ?? [],
                top: min(
                    max(0, rowY - 8),
                    max(0, size.height - InterfaceScale.points(bookmark?.label != nil || bookmark?.tags.isEmpty == false ? 170 : 110))),
                bandMinY: rowY,
                bandHeight: max(1 / max(1, displayScale), CGFloat(max(1, block.lineWidths.count)) * layout.pitch),
                trailingInset: ConversationMapMetrics.columnWidth + 6
            ), at: point)
    }
}

struct ConversationMapCanvas: View, Equatable {
    let outline: ConversationOutline
    let layout: ConversationMapLayout
    let chips: [ConversationMapLayout.Chip]
    let colors: ConversationMapColors
    let pixel: CGFloat
    let chipSide: CGFloat
    let letterFont: Font
    var scrollThumbWidth: CGFloat = 2
    var scrollThumbMinimumLength: CGFloat = 16

    nonisolated static func == (first: Self, second: Self) -> Bool {
        first.outline.revision == second.outline.revision && first.layout == second.layout && first.chips == second.chips
            && first.colors == second.colors && first.pixel == second.pixel && first.chipSide == second.chipSide
            && first.letterFont == second.letterFont && first.scrollThumbWidth == second.scrollThumbWidth
            && first.scrollThumbMinimumLength == second.scrollThumbMinimumLength
    }

    var body: some View {
        Canvas { context, size in
            let barsMinX = ConversationMapMetrics.leadingInset
            let chipX = size.width - ConversationMapMetrics.chipGap - chipSide
            let barsWidth = max(0, chipX - ConversationMapMetrics.chipGap - barsMinX)
            context.fill(Path(CGRect(x: 0, y: 0, width: pixel, height: size.height)), with: .color(Color(hexValue: colors.hairline)))
            if let thumb = layout.scrollThumb(minimumLength: scrollThumbMinimumLength) {
                let rect = CGRect(x: pixel + 1, y: thumb.minY, width: scrollThumbWidth, height: thumb.height)
                context.fill(Capsule().path(in: rect), with: .color(Color(hexValue: colors.hex(for: .toolRun))))
            }
            var paths: [ConversationMapLayout.Ink: Path] = [:]
            for bar in layout.bars(for: outline, pixel: pixel) {
                paths[bar.ink, default: Path()].addRect(
                    CGRect(
                        x: barsMinX, y: bar.minY,
                        width: max(pixel, bar.widthFraction * barsWidth), height: bar.height))
            }
            for ink in ConversationMapLayout.Ink.allCases {
                if let path = paths[ink] { context.fill(path, with: .color(Color(hexValue: colors.hex(for: ink)))) }
            }
            let chipColor = Color(hexValue: colors.chip)
            for chip in chips {
                let minX = ConversationMapLayout.chipMinX(of: chip, width: size.width)
                if chip.rowY >= 0, chip.rowY <= size.height {
                    context.fill(
                        Path(CGRect(x: barsMinX, y: chip.rowY, width: max(0, minX - barsMinX), height: pixel)),
                        with: .color(chipColor))
                }
                let rect = CGRect(x: minX, y: chip.chipY, width: chip.title.width, height: chipSide)
                context.fill(RoundedRectangle(.small).path(in: rect), with: .color(chipColor))
                context.draw(
                    Text(verbatim: chip.title.text).font(letterFont).foregroundStyle(Color(hexValue: colors.chipText)),
                    at: CGPoint(x: rect.midX, y: rect.midY))
            }
        }
        .accessibilityHidden(true)
    }
}

struct ConversationMapChipMenus: View {
    let chips: [ConversationMapLayout.Chip]
    let bookmarks: [MessageBookmark]
    let width: CGFloat
    let side: CGFloat
    let onOpen: (MessageBookmark) -> Void
    let onEdit: (MessageBookmark) -> Void
    let onRemove: (MessageBookmark) -> Void

    var body: some View {
        ForEach(chips, id: \.letter) { chip in
            if let bookmark = bookmarks.first(where: { $0.letter == chip.letter }) {
                Color.clear
                    .frame(width: chip.title.width, height: side)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpen(bookmark) }
                    .contextMenu {
                        Button("Edit bookmark \(bookmark.letter)…") { onEdit(bookmark) }
                        Button("Remove bookmark \(bookmark.letter)") { onRemove(bookmark) }
                    }
                    .offset(x: ConversationMapLayout.chipMinX(of: chip, width: width), y: chip.chipY)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct ConversationMapEmptyState: View {
    let text: LocalizedStringKey
    let color: UInt32

    var body: some View {
        Text(text)
            .font(ThemeFont.caption)
            .foregroundStyle(Color(hexValue: color))
            .multilineTextAlignment(.center)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .top)
            .accessibilityLabel(Text("Conversation map"))
            .accessibilityValue(Text(text))
    }
}

enum ConversationMapAccessibility {
    @MainActor static func value(messageCount: Int, bookmarkCount: Int, language: AppInterfaceLanguage?) -> String {
        let messages =
            messageCount == 1
            ? AppLocalization.string("1 message", language: language)
            : AppLocalization.string("\(messageCount) messages", language: language)
        let bookmarks =
            bookmarkCount == 1
            ? AppLocalization.string("1 bookmark", language: language)
            : AppLocalization.string("\(bookmarkCount) bookmarks", language: language)
        return AppLocalization.string("\(messages), \(bookmarks)", language: language)
    }
}

extension Color {
    init(hexValue: UInt32) {
        self.init(nsColor: NSColor(hexValue: hexValue))
    }
}
