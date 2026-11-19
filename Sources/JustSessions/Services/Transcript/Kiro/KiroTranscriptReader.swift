import Foundation

struct KiroTranscriptReader {
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
        if let payload = record["payload"] as? [String: Any] {
            appendV3(payload, timestamp: ConversationMetadata.date(record["timestamp"]), to: &builder)
            return
        }
        guard let data = record["data"] as? [String: Any],
            let content = data["content"] as? [[String: Any]]
        else { return }
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
                    let arguments =
                        (tool["input"] as? [String: Any])
                        ?? (tool["input"] as? String).flatMap { ConversationMetadata.object(from: Data($0.utf8)) }
                        ?? [:]
                    builder.append(
                        .toolCall,
                        text: ToolCallSummary.summary(toolName: tool["name"] as? String ?? "Tool", arguments: arguments),
                        timestamp: timestamp
                    )
                default:
                    continue
                }
            }
        default:
            return
        }
    }

    /// A V3 event. Your prompt is `user`, the reply `assistant` with `operationType` `Say`, and a tool `tool_call`, its
    /// `args` an object. Reasoning (`Reasoning`), tool results, turns, approvals, usage, the system prompt Kiro keeps as
    /// `session_start`, and the context it adds for the model as `agent_note` (Kiro CLI 2.34.0) stay out, as V2's thinking
    /// and tool outputs do.
    private func appendV3(_ payload: [String: Any], timestamp: Date?, to builder: inout TranscriptBuilder) {
        switch payload["type"] as? String {
        case "user":
            let images = Array(repeating: "[Image]", count: (payload["images"] as? [Any])?.count ?? 0)
            builder.append(
                .userMessage, text: ([payload["content"] as? String ?? ""] + images).joined(separator: "\n\n"),
                timestamp: timestamp)
        case "assistant":
            guard payload["operationType"] as? String != "Reasoning" else { return }
            builder.append(.assistantMessage, text: payload["content"] as? String ?? "", timestamp: timestamp)
        case "tool_call":
            let arguments =
                (payload["args"] as? [String: Any])
                ?? (payload["args"] as? String).flatMap { ConversationMetadata.object(from: Data($0.utf8)) }
                ?? [:]
            builder.append(
                .toolCall,
                text: ToolCallSummary.summary(
                    toolName: payload["toolName"] as? String ?? payload["title"] as? String ?? "Tool",
                    arguments: arguments),
                timestamp: timestamp
            )
        default:
            return
        }
    }
}
