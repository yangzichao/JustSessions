import Foundation

/// Reads the visible conversation from a Pi session file (`~/.pi/agent/sessions/<project>/<timestamp>_<id>.jsonl`).
/// The file holds every branch of the session, so it is read twice: once to find the current branch from how its
/// entries link together, then again to decode only that branch's entries.
struct PiTranscriptReader {
    /// Marks where the user went back to an earlier message and Pi summarized the branch they left.
    static let branchSummaryNoteText = "Returned to an earlier message; the branch left behind was summarized"

    func read(_ file: URL) throws -> TranscriptContent {
        var links: [PiEntryLink] = []
        var lineCount = 0
        try JSONLinesReader.forEachLine(in: file) { line in
            if let link = PiEntryLink(line: line, lineIndex: lineCount) { links.append(link) }
            lineCount += 1
        }
        // Lines Pi appends after the first pass have higher indices than any of these, so they are left out.
        var remainingLineIndices = PiActiveBranch.entries(in: links).filter(\.mightBeShown).map(\.lineIndex)[...]

        var builder = TranscriptBuilder()
        var lineIndex = 0
        try JSONLinesReader.forEachLine(in: file) { line in
            defer { lineIndex += 1 }
            guard remainingLineIndices.first == lineIndex else { return }
            remainingLineIndices.removeFirst()
            guard let record = ConversationMetadata.object(from: line) else { return }
            append(record, to: &builder)
        }
        return builder.build()
    }

    func append(_ record: [String: Any], to builder: inout TranscriptBuilder) {
        let timestamp = ConversationMetadata.date(record["timestamp"])
        switch record["type"] as? String {
        case "message":
            guard let message = record["message"] as? [String: Any] else { return }
            appendMessage(message, timestamp: timestamp, to: &builder)
        case "compaction":
            builder.appendCompactionNote(timestamp: timestamp)
        case "branch_summary":
            builder.append(.note, text: Self.branchSummaryNoteText, timestamp: timestamp)
        default:
            // Extension messages (`custom_message`) are context injected for the model, like the tagged text the
            // other readers leave out; the rest record settings, labels, names, and usage.
            return
        }
    }

    private func appendMessage(_ message: [String: Any], timestamp: Date?, to builder: inout TranscriptBuilder) {
        switch message["role"] as? String {
        case "user":
            builder.append(.userMessage, text: userText(from: message["content"]), timestamp: timestamp)
        case "bashExecution":
            // `!!` runs a command whose output is kept out of the model's context.
            let prefix = message["excludeFromContext"] as? Bool == true ? "!!" : "!"
            let command = (message["command"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return }
            builder.append(.userMessage, text: prefix + command, timestamp: timestamp)
        case "assistant":
            for part in message["content"] as? [[String: Any]] ?? [] {
                switch part["type"] as? String {
                case "text":
                    builder.append(.assistantMessage, text: part["text"] as? String ?? "", timestamp: timestamp)
                case "toolCall":
                    let summary = ToolCallSummary.summary(
                        toolName: part["name"] as? String ?? "tool",
                        arguments: part["arguments"] as? [String: Any] ?? [:]
                    )
                    builder.append(.toolCall, text: summary, timestamp: timestamp)
                default:
                    continue // Thinking blocks are left out of the preview.
                }
            }
            if message["stopReason"] as? String == "error" {
                builder.append(.note, text: message["errorMessage"] as? String ?? "", timestamp: timestamp)
            }
        default:
            // Tool results are shown through the tool call that produced them. System messages carry the prompt
            // and tools, not conversation.
            return
        }
    }

    private func userText(from content: Any?) -> String {
        if let text = content as? String { return visibleUserText(text) }
        let parts = content as? [[String: Any]] ?? []
        return parts.compactMap { part -> String? in
            switch part["type"] as? String {
            case "text": visibleUserText(part["text"] as? String ?? "")
            case "image": "[Image]"
            default: nil
            }
        }.joined(separator: "\n\n")
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
