import Foundation

/// Reads Kiro's visible prompts, replies, and tool calls from its append-only session log.
struct KiroTranscriptReader {
    func read(_ file: URL) throws -> TranscriptContent {
        var builder = TranscriptBuilder()
        try JSONLinesReader.forEachLine(in: file) { line in
            guard let record = ConversationMetadata.object(from: line) else { return }
            append(record, to: &builder)
        }
        return builder.build()
    }

    func append(_ record: [String: Any], to builder: inout TranscriptBuilder) {
        guard let data = record["data"] as? [String: Any],
              let content = data["content"] as? [[String: Any]] else { return }
        let timestamp = KiroTranscriptTimestamp.date(in: record, data: data)
        switch record["kind"] as? String {
        case "Prompt":
            let text = content.compactMap { part -> String? in
                switch part["kind"] as? String {
                case "text": part["data"] as? String
                case "image": "[Image]"
                default: nil
                }
            }.joined(separator: "\n\n")
            builder.append(.userMessage, text: text, timestamp: timestamp)
        case "AssistantMessage":
            for part in content {
                switch part["kind"] as? String {
                case "text":
                    builder.append(.assistantMessage, text: part["data"] as? String ?? "", timestamp: timestamp)
                case "toolUse":
                    guard let tool = part["data"] as? [String: Any] else { continue }
                    let arguments = (tool["input"] as? [String: Any])
                        ?? (tool["input"] as? String).flatMap { ConversationMetadata.object(from: Data($0.utf8)) }
                        ?? [:]
                    builder.append(
                        .toolCall,
                        text: ToolCallSummary.summary(toolName: tool["name"] as? String ?? "Tool", arguments: arguments),
                        timestamp: timestamp
                    )
                default:
                    continue // Thinking and tool outputs stay out of the conversation preview.
                }
            }
        default:
            return // System context and ToolResults are not visible conversation messages.
        }
    }
}
