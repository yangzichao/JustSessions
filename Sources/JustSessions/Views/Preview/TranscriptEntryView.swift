import SwiftUI

struct TranscriptEntryView: View {
    let entry: TranscriptEntry
    let assistantName: String
    let assistantNameColor: ThemeColor
    @Environment(\.transcriptReadingFontSize) private var fontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.startsTurn {
                speakerLabel
            } else if isBookmarkable {
                TranscriptBookmarkLabel()
            }
            entryContent
        }
        .font(.system(size: fontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Self.topPadding(startsTurn: entry.startsTurn))
    }

    private var isBookmarkable: Bool { MessageBookmark.Kind(entry.content) != nil }

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
            TranscriptTextBlock(
                source: AttributedString(text),
                style: TranscriptTextStyle(
                    fontSize: TranscriptReadingTextSize.noteSize(forReadingSize: fontSize), lineSpacing: 0, tone: .tertiary)
            )
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
