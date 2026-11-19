import SwiftUI

struct TranscriptEntryView: View {
    let entry: TranscriptEntry
    let assistantName: String
    /// The CLI's name above its messages is in its hue.
    let assistantNameColor: ThemeColor
    @Environment(\.transcriptReadingFontSize) private var fontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.startsTurn {
                speakerLabel
            } else if isBookmarkable {
                // A labelled bookmark's label, on a line of its own, spaced as a speaker's line, where none has room
                // for it. Empty, it takes no space.
                TranscriptBookmarkLabel()
            }
            entryContent
        }
        .font(.system(size: fontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Self.topPadding(startsTurn: entry.startsTurn))
    }

    /// Your messages and the CLI's replies, which can be bookmarked (RDR-48).
    private var isBookmarkable: Bool { MessageBookmark.Kind(entry.content) != nil }

    /// Space above an entry, more where a speaker's turn starts; `TranscriptBookmarkMarker` lines up with it.
    static func topPadding(startsTurn: Bool) -> CGFloat { startsTurn ? 28 : 12 }

    @ViewBuilder
    private var entryContent: some View {
        switch entry.content {
        case .userMessage(let text):
            TranscriptTextBlock(source: AttributedString(text), style: TranscriptTextStyle(fontSize: fontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ThemePalette.userMessageSurface, in: RoundedRectangle(.panel))
        case .assistantMessage(let text):
            TranscriptMarkdownView(text: text, prepared: entry.markdown)
        case .toolCalls(let summaries):
            TranscriptToolCallsView(summaries: summaries)
        case .note(let text):
            // ThemeFont.caption's size.
            TranscriptTextBlock(source: AttributedString(text), style: TranscriptTextStyle(fontSize: 10, lineSpacing: 0, tone: .tertiary))
                .frame(maxWidth: .infinity)
        case .userImage(let image), .toolResultImage(let image):
            TranscriptImageView(image: image)
        }
    }

    private var speakerLabel: some View {
        let isUser =
            switch entry.content {
            case .userMessage, .userImage: true
            default: false
            }
        return HStack(spacing: 6) {
            Group {
                if isUser { Text("You") } else { Text(verbatim: assistantName) }
            }
            .font(ThemeFont.callout.weight(.semibold))
            .foregroundStyle(isUser ? ThemePalette.secondaryText : assistantNameColor)
            if let timestamp = entry.timestamp {
                Text(timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(ThemeFont.detail)
                    .foregroundStyle(ThemePalette.tertiaryText)
            }
            if isBookmarkable { TranscriptBookmarkLabel() }
        }
    }

}
