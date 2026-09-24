import SwiftUI

struct TranscriptEntryView: View {
    let entry: TranscriptEntry
    let assistantName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.startsTurn { speakerLabel }
            entryContent
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, entry.startsTurn ? 20 : 8)
    }

    @ViewBuilder
    private var entryContent: some View {
        switch entry.content {
        case .userMessage(let text):
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        case .assistantMessage(let text):
            Text(Self.inlineMarkdown(text))
                .textSelection(.enabled)
                .lineSpacing(2)
        case .toolCalls(let summaries):
            ToolCallsRow(summaries: summaries)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if let timestamp = entry.timestamp {
                Text(timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Bold, italics, inline code, and links; line breaks are kept as written.
    private static func inlineMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// A run of tool calls: one line, or a collapsed group that expands to every call.
private struct ToolCallsRow: View {
    let summaries: [String]
    @State private var isExpanded = false

    var body: some View {
        if summaries.count == 1 {
            summaryLine(summaries[0])
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(summaries.enumerated()), id: \.offset) { _, summary in
                        summaryLine(summary)
                    }
                }
                .padding(.top, 4)
            } label: {
                Label("\(summaries.count) tool calls", systemImage: "wrench.and.screwdriver")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryLine(_ summary: String) -> some View {
        Label {
            Text(summary)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "wrench.and.screwdriver").font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
        .help(summary)
    }
}
