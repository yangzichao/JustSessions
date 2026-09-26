import Foundation

/// Reads the visible conversation from a Claude Code session file (`~/.claude/projects/<project>/<session>.jsonl`).
struct ClaudeTranscriptReader {
    func read(_ file: URL) throws -> TranscriptContent {
        var builder = TranscriptBuilder()
        try JSONLinesReader.forEachLine(in: file) { line in
            guard let record = ConversationMetadata.object(from: line) else { return }
            append(record, to: &builder)
        }
        return builder.build()
    }

    func append(_ record: [String: Any], to builder: inout TranscriptBuilder) {
        let recordType = record["type"] as? String
        guard recordType == "user" || recordType == "assistant",
              record["isSidechain"] as? Bool != true,
              record["isMeta"] as? Bool != true,
              let message = record["message"] as? [String: Any] else { return }
        let timestamp = ConversationMetadata.date(record["timestamp"])

        if record["isCompactSummary"] as? Bool == true {
            builder.appendCompactionNote(timestamp: timestamp)
        } else if recordType == "user" {
            builder.append(.userMessage, text: userText(from: message["content"]), timestamp: timestamp)
        } else if record["isApiErrorMessage"] as? Bool == true {
            builder.append(.note, text: assistantParts(from: message["content"]).map(\.text).joined(separator: "\n"), timestamp: timestamp)
        } else {
            for part in assistantParts(from: message["content"]) {
                builder.append(part.kind, text: part.text, timestamp: timestamp)
            }
        }
    }

    private func userText(from content: Any?) -> String {
        if let text = content as? String { return visibleUserText(text) ?? "" }
        let parts = content as? [[String: Any]] ?? []
        return parts.compactMap { part -> String? in
            switch part["type"] as? String {
            case "text": visibleUserText(part["text"] as? String ?? "")
            case "image": "[Image]"
            default: nil // Tool results are shown through the tool call that produced them.
            }
        }.joined(separator: "\n\n")
    }

    /// Claude Code stores slash commands, shell escapes, and injected context as tagged user text.
    private func visibleUserText(_ text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.hasPrefix("<") else { return trimmedText }
        if let commandName = taggedValue("command-name", in: trimmedText) {
            let commandArguments = taggedValue("command-args", in: trimmedText) ?? ""
            return commandArguments.isEmpty ? commandName : "\(commandName) \(commandArguments)"
        }
        if let shellCommand = taggedValue("bash-input", in: trimmedText) {
            return "! \(shellCommand)"
        }
        return nil
    }

    private func taggedValue(_ tag: String, in text: String) -> String? {
        guard let start = text.range(of: "<\(tag)>"),
              let end = text.range(of: "</\(tag)>", range: start.upperBound..<text.endIndex) else { return nil }
        let value = text[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func assistantParts(from content: Any?) -> [(kind: TranscriptBuilder.EntryKind, text: String)] {
        if let text = content as? String { return [(.assistantMessage, text)] }
        let parts = content as? [[String: Any]] ?? []
        return parts.compactMap { part in
            switch part["type"] as? String {
            case "text":
                return (.assistantMessage, part["text"] as? String ?? "")
            case "tool_use":
                let summary = ToolCallSummary.summary(
                    toolName: part["name"] as? String ?? "Tool",
                    arguments: part["input"] as? [String: Any] ?? [:]
                )
                return (.toolCall, summary)
            default:
                return nil // Thinking blocks are left out of the preview.
            }
        }
    }
}
