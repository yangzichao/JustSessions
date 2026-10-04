import Foundation

/// Reads the visible conversation from a Claude Code session file (`~/.claude/projects/<project>/<session>.jsonl`).
struct ClaudeTranscriptReader {
    var maximumEntryCount = 2_000
    var maximumTextLength = 12_000

    func read(_ file: URL) throws -> TranscriptContent {
        var builder = TranscriptBuilder(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength)
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
            for part in message["content"] as? [[String: Any]] ?? [] {
                switch part["type"] as? String {
                case "image":
                    if let image = Self.image(from: part) { builder.appendUserImage(image, timestamp: timestamp) }
                case "tool_result":
                    for resultPart in part["content"] as? [[String: Any]] ?? [] {
                        if let image = Self.image(from: resultPart) { builder.appendToolResultImage(image, timestamp: timestamp) }
                    }
                default:
                    continue
                }
            }
        } else if record["isApiErrorMessage"] as? Bool == true {
            builder.append(.note, text: assistantParts(from: message["content"]).map(\.text).joined(separator: "\n"), timestamp: timestamp)
        } else {
            for part in assistantParts(from: message["content"]) {
                builder.append(part.kind, text: part.text, timestamp: timestamp)
            }
        }
    }

    /// The text of a user message; its images follow it as entries of their own. A tool result's text is shown
    /// through the tool call that produced it.
    private func userText(from content: Any?) -> String {
        if let text = content as? String { return visibleUserText(text) ?? "" }
        let parts = content as? [[String: Any]] ?? []
        return parts
            .compactMap { part in part["type"] as? String == "text" ? visibleUserText(part["text"] as? String ?? "") : nil }
            .joined(separator: "\n\n")
    }

    /// The image of an `image` part, which Claude Code stores as `{"source":{"type":"base64","data":…}}`.
    private static func image(from part: [String: Any]) -> TranscriptImage? {
        guard part["type"] as? String == "image",
              let source = part["source"] as? [String: Any],
              let data = source["data"] as? String else { return nil }
        return TranscriptImage(base64Encoded: data)
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
