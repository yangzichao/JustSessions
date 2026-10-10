import Foundation

/// Reads the visible conversation from a Pi session file (`~/.pi/agent/sessions/<project>/<timestamp>_<id>.jsonl`).
/// The file holds every branch of the session, so it is read twice: once to find the current branch from how its
/// entries link together, then again to decode only that branch's entries.
struct PiTranscriptReader {
    var maximumEntryCount = 2_000
    var maximumTextLength = 12_000
    /// Marks where the user went back to an earlier message and Pi summarized the branch they left.
    static let branchSummaryNoteText = "Returned to an earlier message; the branch left behind was summarized"

    func read(_ file: URL) throws -> TranscriptContent {
        let decoder = JSONDecoder()
        var links: [PiEntryLink] = []
        var lineCount = 0
        try JSONLinesReader.forEachLine(in: file) { line in
            if let link = PiEntryLink(line: line, lineIndex: lineCount, decoder: decoder) { links.append(link) }
            lineCount += 1
        }
        // Lines Pi appends after the first pass have higher indices than any of these, so they are left out.
        var remainingLineIndices = PiActiveBranch.entries(in: links).filter(\.mightBeShown).map(\.lineIndex)[...]

        var builder = TranscriptBuilder(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength)
        var lineIndex = 0
        try JSONLinesReader.forEachLine(in: file) { line in
            defer { lineIndex += 1 }
            guard remainingLineIndices.first == lineIndex else { return }
            remainingLineIndices.removeFirst()
            guard let entry = try? decoder.decode(PiSessionEntry.self, from: line) else { return }
            append(entry, to: &builder)
        }
        return builder.build()
    }

    func append(_ entry: PiSessionEntry, to builder: inout TranscriptBuilder) {
        guard let previewedEntry = entry.previewedEntry else { return }
        let timestamp = entry.timestamp.flatMap(ISO8601TimestampParser.shared.date(from:))
        let message = entry.message
        switch previewedEntry {
        case .userMessage:
            builder.append(.userMessage, text: userText(from: message?.content), timestamp: timestamp)
            for base64 in Self.imageBase64Strings(in: message?.content) {
                builder.appendUserImage(TranscriptImage(base64Encoded: base64), timestamp: timestamp)
            }
        case .shellCommand:
            // `!!` runs a command whose output is kept out of the model's context.
            let prefix = message?.excludeFromContext == true ? "!!" : "!"
            let command = (message?.command ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return }
            builder.append(.userMessage, text: prefix + command, timestamp: timestamp)
        case .assistantMessage:
            for part in Self.parts(of: message?.content) {
                switch part.type {
                case "text":
                    builder.append(.assistantMessage, text: part.text ?? "", timestamp: timestamp)
                case "toolCall":
                    let summary = ToolCallSummary.summary(
                        toolName: part.name ?? "tool",
                        arguments: part.arguments?.foundationValue as? [String: Any] ?? [:]
                    )
                    builder.append(.toolCall, text: summary, timestamp: timestamp)
                default:
                    continue // Thinking blocks are left out of the preview.
                }
            }
            if message?.stopReason == "error" {
                builder.append(.note, text: message?.errorMessage ?? "", timestamp: timestamp)
            }
        case .toolResult:
            for base64 in Self.imageBase64Strings(in: message?.content) {
                builder.appendToolResultImage(TranscriptImage(base64Encoded: base64), timestamp: timestamp)
            }
        case .compaction:
            builder.appendCompactionNote(timestamp: timestamp)
        case .branchSummary:
            builder.append(.note, text: Self.branchSummaryNoteText, timestamp: timestamp)
        }
    }

    /// The text of a user message; its images follow it as entries of their own.
    private func userText(from content: PiSessionEntry.Message.Content?) -> String {
        if case .text(let text) = content { return visibleUserText(text) }
        return Self.parts(of: content)
            .compactMap { part in part.type == "text" ? visibleUserText(part.text ?? "") : nil }
            .joined(separator: "\n\n")
    }

    /// The parts of `content`; none when it is plain text or missing.
    private static func parts(of content: PiSessionEntry.Message.Content?) -> [PiSessionEntry.Message.Part] {
        guard case .parts(let parts) = content else { return [] }
        return parts
    }

    private static func imageBase64Strings(in content: PiSessionEntry.Message.Content?) -> [String] {
        parts(of: content).compactMap(\.imageBase64)
    }

    /// Pi expands `/skill:name arguments` into the skill's instructions, wrapped as
    /// `<skill name="…" location="…">\n…\n</skill>`, followed by the arguments. That shows as what the user typed.
    private func visibleUserText(_ text: String) -> String {
        let skillPrefix = "<skill name=\""
        let skillEnd = "\n</skill>"
        guard text.hasPrefix(skillPrefix),
              let blockEnd = text.range(of: skillEnd) else { return text }
        let skillName = text.dropFirst(skillPrefix.count).prefix { $0 != "\"" }
        let arguments = text[blockEnd.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let command = "/skill:\(skillName)"
        return arguments.isEmpty ? command : "\(command) \(arguments)"
    }
}
