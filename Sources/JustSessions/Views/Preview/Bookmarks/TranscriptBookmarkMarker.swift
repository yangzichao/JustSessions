import Observation
import SwiftUI

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
    @Entry var transcriptBookmarkHover: TranscriptBookmarkHover? = nil
}

struct TranscriptBookmarkMarker: View {
    @MainActor static var side: CGFloat { min(InterfaceScale.points(16), TranscriptColumnLayout.gutterWidth - gapToText) }
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

@MainActor
@Observable
final class TranscriptBookmarkHover {
    nonisolated static let coordinateSpace = "TranscriptBookmarkHover"

    struct Card: Equatable {
        let bookmark: MessageBookmark
        let point: CGPoint
    }

    private(set) var card: Card?

    func show(_ bookmark: MessageBookmark, at point: CGPoint) {
        guard card?.bookmark != bookmark else { return }
        card = Card(bookmark: bookmark, point: point)
    }

    func hide(_ bookmark: MessageBookmark? = nil) {
        guard let card, bookmark == nil || card.bookmark.letter == bookmark?.letter else { return }
        self.card = nil
    }
}

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
        .accessibilityHidden(true)
    }
}

extension View {
    func transcriptBookmarkHoverCard(_ hover: TranscriptBookmarkHover) -> some View {
        environment(\.transcriptBookmarkHover, hover)
            .coordinateSpace(.named(TranscriptBookmarkHover.coordinateSpace))
            .overlay(alignment: .topLeading) { TranscriptBookmarkHoverCard(hover: hover) }
    }
}
