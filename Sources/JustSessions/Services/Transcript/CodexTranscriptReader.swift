import Foundation

/// Reads the visible conversation from a Codex rollout file (`~/.codex/sessions/**/rollout-*.jsonl`).
struct CodexTranscriptReader {
    private static let transcriptPayloadTypes: Set<String> = ["message", "function_call", "custom_tool_call"]

    func read(_ file: URL) throws -> TranscriptContent {
        var builder = TranscriptBuilder()
        try JSONLinesReader.forEachLine(in: file) { line in
            guard Self.mightContainTranscriptItem(line),
                  let record = ConversationMetadata.object(from: line) else { return }
            append(record, to: &builder)
        }
        return builder.build()
    }

    /// Checks the start of a line so events and tool outputs, usually most of a rollout's bytes,
    /// are skipped without JSON parsing. Only Codex's own layout is judged this way:
    /// `{"timestamp":…,"type":"…","payload":{"type":"…"`, where the record's `type` comes before anything nested
    /// (Codex puts an `ordinal` number between). Any other line is parsed.
    static func mightContainTranscriptItem(_ line: Data) -> Bool {
        let head = String(decoding: line.prefix(512), as: UTF8.self)
        // A quote right after a comma cannot be inside a string, and with no `{` or `[` before it, this `type` is
        // the record's own rather than one inside the payload.
        guard head.hasPrefix("{\"timestamp\":"),
              let recordTypeMarker = head.range(of: ",\"type\":\""),
              !head[..<recordTypeMarker.lowerBound].dropFirst().contains(where: { $0 == "{" || $0 == "[" }),
              let recordType = plainStringValue(startingAt: recordTypeMarker.upperBound, in: head)
        else { return true }
        if recordType.value == "compacted" { return true }
        guard recordType.value == "response_item" else { return false }

        let payloadTypeMarker = ",\"payload\":{\"type\":\""
        let afterRecordType = head[recordType.end...]
        guard afterRecordType.hasPrefix(payloadTypeMarker),
              let payloadType = plainStringValue(
                  startingAt: afterRecordType.dropFirst(payloadTypeMarker.count).startIndex,
                  in: head
              )
        else { return true }
        return transcriptPayloadTypes.contains(payloadType.value)
    }

    /// The string value starting at `start` and the index after its closing quote. Nil when the value is cut off
    /// or holds an escape, which could spell a type differently, so the line is parsed instead.
    private static func plainStringValue(startingAt start: String.Index, in text: String) -> (value: String, end: String.Index)? {
        guard let closingQuote = text[start...].firstIndex(of: "\""),
              !text[start..<closingQuote].contains("\\") else { return nil }
        return (String(text[start..<closingQuote]), text.index(after: closingQuote))
    }

    func append(_ record: [String: Any], to builder: inout TranscriptBuilder) {
        let timestamp = ConversationMetadata.date(record["timestamp"])
        if record["type"] as? String == "compacted" {
            builder.appendCompactionNote(timestamp: timestamp)
            return
        }
        guard record["type"] as? String == "response_item",
              let payload = record["payload"] as? [String: Any] else { return }

        switch payload["type"] as? String {
        case "message":
            let content = payload["content"] as? [[String: Any]] ?? []
            switch payload["role"] as? String {
            case "user":
                builder.append(.userMessage, text: userText(from: content), timestamp: timestamp)
            case "assistant":
                let text = content
                    .compactMap { $0["type"] as? String == "output_text" ? $0["text"] as? String : nil }
                    .joined(separator: "\n\n")
                builder.append(.assistantMessage, text: text, timestamp: timestamp)
            default:
                return // Developer messages are instructions, not conversation.
            }
        case "function_call":
            let arguments = (payload["arguments"] as? String)
                .flatMap { ConversationMetadata.object(from: Data($0.utf8)) } ?? [:]
            builder.append(
                .toolCall,
                text: ToolCallSummary.summary(toolName: payload["name"] as? String ?? "tool", arguments: arguments),
                timestamp: timestamp
            )
        case "custom_tool_call":
            builder.append(
                .toolCall,
                text: ToolCallSummary.summary(
                    toolName: payload["name"] as? String ?? "tool",
                    freeformInput: payload["input"] as? String ?? ""
                ),
                timestamp: timestamp
            )
        default:
            return
        }
    }

    private func userText(from content: [[String: Any]]) -> String {
        content.compactMap { part -> String? in
            switch part["type"] as? String {
            case "input_text":
                let text = (part["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                // Codex sends AGENTS.md, environment context, and similar tagged blocks as user input.
                return text.hasPrefix("<") || text.hasPrefix("# AGENTS.md") ? nil : text
            case "input_image":
                return "[Image]"
            default:
                return nil
            }
        }.joined(separator: "\n\n")
    }
}
