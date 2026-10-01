import SwiftUI

struct TranscriptEntryView: View {
    let entry: TranscriptEntry
    let assistantName: String
    let assistantTint: Color
    @Environment(\.transcriptReadingFontSize) private var fontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.startsTurn { speakerLabel }
            entryContent
        }
        .font(.system(size: fontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, entry.startsTurn ? 28 : 12)
    }

    @ViewBuilder
    private var entryContent: some View {
        switch entry.content {
        case .userMessage(let text):
            Text(text)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ThemePalette.userMessageSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .assistantMessage(let text):
            TranscriptMarkdownView(text: text)
        case .toolCalls(let summaries):
            TranscriptToolCallsView(summaries: summaries)
        case .note(let text):
            Text(text)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }

    private var speakerLabel: some View {
        let isUser = if case .userMessage = entry.content { true } else { false }
        return HStack(spacing: 6) {
            Text(isUser ? "You" : assistantName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isUser ? Color.secondary : assistantTint)
            if let timestamp = entry.timestamp {
                Text(timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

}
