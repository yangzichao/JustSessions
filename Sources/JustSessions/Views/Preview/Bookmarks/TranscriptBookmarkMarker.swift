import Observation
import SwiftUI

/// The reader's bookmarks by entry ID. Only `TranscriptBookmarkMarker` reads it, so a new bookmark, label, or tag redraws
/// markers and leaves the entries, their layout, and their text alone.
struct TranscriptBookmarkLetters: Equatable {
    private(set) var bookmarksByEntryID: [Int: MessageBookmark] = [:]

    init(_ bookmarks: [MessageBookmark] = []) {
        bookmarksByEntryID = Dictionary(bookmarks.map { ($0.entryID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func letter(forEntryID entryID: Int) -> String? { bookmarksByEntryID[entryID]?.letter }
    func bookmark(forEntryID entryID: Int) -> MessageBookmark? { bookmarksByEntryID[entryID] }
}

extension EnvironmentValues {
    @Entry var transcriptBookmarkLetters = TranscriptBookmarkLetters()
    /// The reader's one hover card for bookmark letters; nil leaves the letters inert, as in tests.
    @Entry var transcriptBookmarkHover: TranscriptBookmarkHover? = nil
}

/// A bookmarked message's letter in the transcript's 24-point gutter, beside its first line. A letter whose bookmark has a
/// label or tags shows them in the reader's card while the pointer is on it (RDR-51); any other letter is inert to the
/// pointer, so the reader keeps at most 26 hover areas.
struct TranscriptBookmarkMarker: View {
    /// The chip's side: 20 + 4 fills the 24-point gutter (TranscriptScrollView's padding).
    @MainActor static var side: CGFloat { min(InterfaceScale.points(16), 20) }
    /// Between the chip and the text.
    static let gapToText: CGFloat = 4

    let entryID: Int
    let topPadding: CGFloat
    @Environment(\.transcriptBookmarkLetters) private var letters
    @Environment(\.transcriptBookmarkHover) private var hover

    var body: some View {
        if let bookmark = letters.bookmark(forEntryID: entryID) {
            let side = Self.side
            let hasDetails = bookmark.label != nil || !bookmark.tags.isEmpty
            Text(verbatim: bookmark.letter)
                .font(ThemeFont.caption.weight(.semibold))
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: side, height: side)
                .background(ThemePalette.trackFill, in: RoundedRectangle(.small))
                .contentShape(Rectangle())
                .onContinuousHover(coordinateSpace: .named(TranscriptBookmarkHover.coordinateSpace)) { phase in
                    guard hasDetails, let hover else { return }
                    switch phase {
                    case .active(let point): hover.show(bookmark, at: point)
                    case .ended: hover.hide(bookmark)
                    }
                }
                .allowsHitTesting(hasDetails && hover != nil)
                .padding(.top, topPadding)
                // In the gutter, left of the text. The leading alignment guide this used, set from the chip's trailing edge, left
                // the chip over the text's first characters in a rendering of the reader (performance.md item 34).
                .offset(x: -(side + Self.gapToText))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Self.accessibilityLabel(of: bookmark)))
        }
    }

    /// "Bookmark a", then its label and tags, which VoiceOver can't hover for.
    static func accessibilityLabel(of bookmark: MessageBookmark) -> String {
        [
            AppLocalization.string("Bookmark \(bookmark.letter)"), bookmark.label,
            bookmark.tags.isEmpty ? nil : MessageBookmarkDetails.typedText(of: bookmark.tags),
        ]
        .compactMap { $0 }.joined(separator: ", ")
    }
}

/// The bookmark letter under the pointer in one reader, read only by `TranscriptBookmarkHoverCard`'s body, so hovering
/// redraws neither the entries nor the markers.
@MainActor
@Observable
final class TranscriptBookmarkHover {
    nonisolated static let coordinateSpace = "TranscriptBookmarkHover"

    struct Card: Equatable {
        let bookmark: MessageBookmark
        /// The pointer, in the reader's coordinates.
        let point: CGPoint
    }

    private(set) var card: Card?

    func show(_ bookmark: MessageBookmark, at point: CGPoint) {
        // Only a new letter moves the card: it stays put while the pointer moves over the same one.
        guard card?.bookmark != bookmark else { return }
        card = Card(bookmark: bookmark, point: point)
    }

    /// Only that letter's card: the next letter's may have shown already.
    func hide(_ bookmark: MessageBookmark? = nil) {
        guard let card, bookmark == nil || card.bookmark.letter == bookmark?.letter else { return }
        self.card = nil
    }
}

/// The card beside the letter under the pointer: its letter, label, and tags, as the map's card shows them (TAB-10).
struct TranscriptBookmarkHoverCard: View {
    let hover: TranscriptBookmarkHover
    private static let width: CGFloat = 280

    var body: some View {
        GeometryReader { geometry in
            if let card = hover.card {
                TabHoverCardSurface {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bookmark \(card.bookmark.letter)")
                            .font(ThemeFont.caption)
                            .foregroundStyle(ThemePalette.secondaryText)
                        if let label = card.bookmark.label {
                            Text(verbatim: label)
                                .font(ThemeFont.callout.weight(.semibold))
                                .foregroundStyle(ThemePalette.ink)
                                .lineLimit(3)
                        }
                        MessageBookmarkTagList(tags: card.bookmark.tags)
                    }
                    .frame(maxWidth: Self.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .fixedSize()
                .offset(
                    x: min(card.point.x + 14, max(0, geometry.size.width - Self.width - 24)),
                    y: max(0, card.point.y - 10))
            }
        }
        .allowsHitTesting(false)
        // The letter's own label says this.
        .accessibilityHidden(true)
    }
}

extension View {
    /// The reader's hover card for bookmark letters, over `content`, whose coordinates the letters report.
    func transcriptBookmarkHoverCard(_ hover: TranscriptBookmarkHover) -> some View {
        environment(\.transcriptBookmarkHover, hover)
            .coordinateSpace(.named(TranscriptBookmarkHover.coordinateSpace))
            .overlay(alignment: .topLeading) { TranscriptBookmarkHoverCard(hover: hover) }
    }
}
