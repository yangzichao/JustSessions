import Observation
import SwiftUI

@MainActor
@Observable
final class ConversationMapHover {
    struct Card: Equatable {
        let blockIndex: Int
        let revision: Int
        let speaker: String
        let timestamp: Date?
        let snippet: String
        let letter: String?
        var label: String? = nil
        var tags: [String] = []
        let top: CGFloat
        let bandMinY: CGFloat
        let bandHeight: CGFloat
        let trailingInset: CGFloat
    }

    private(set) var card: Card?
    @ObservationIgnored private(set) var point: CGPoint?

    func show(_ card: Card, at point: CGPoint) {
        self.point = point
        if self.card != card { self.card = card }
    }

    func hide() {
        point = nil
        if card != nil { card = nil }
    }
}

struct ConversationMapHoverCard: View {
    let hover: ConversationMapHover

    var body: some View {
        if let card = hover.card {
            TabHoverCardSurface {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(verbatim: card.speaker)
                            .font(ThemeFont.callout.weight(.semibold))
                            .foregroundStyle(ThemePalette.ink)
                        if let timestamp = card.timestamp {
                            Text(timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(ThemeFont.caption)
                                .foregroundStyle(ThemePalette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        if let letter = card.letter {
                            Text("Bookmark \(letter)")
                                .font(ThemeFont.caption)
                                .foregroundStyle(ThemePalette.secondaryText)
                        }
                    }
                    if let label = card.label {
                        Text(verbatim: label)
                            .font(ThemeFont.callout.weight(.semibold))
                            .foregroundStyle(ThemePalette.ink)
                            .lineLimit(2)
                    }
                    if !card.snippet.isEmpty {
                        Text(verbatim: card.snippet)
                            .font(ThemeFont.callout)
                            .foregroundStyle(card.label == nil ? ThemePalette.ink : ThemePalette.secondaryText)
                            .lineLimit(3)
                    }
                    MessageBookmarkTagList(tags: card.tags)
                }
            }
            .padding(.trailing, card.trailingInset)
            .offset(y: card.top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct ConversationMapHoverBand: View {
    let hover: ConversationMapHover
    let color: UInt32

    var body: some View {
        if let card = hover.card {
            Rectangle()
                .fill(Color(hexValue: color))
                .frame(height: card.bandHeight)
                .offset(y: card.bandMinY)
                .allowsHitTesting(false)
        }
    }
}
