import Foundation
import SQLite3

/// Reads one session's visible conversation from OpenCode's database, which holds every session. It shows what
/// OpenCode's own session view shows: prompts without the text OpenCode adds to them, replies, and tool calls.
struct OpenCodeTranscriptReader {
    var maximumEntryCount = 2_000
    var maximumTextLength = 12_000
    /// Stands in for the messages OpenCode hides after `/undo`.
    static let undoneMessagesNoteText = "Later messages were undone; /redo in OpenCode restores them"

    func read(_ databaseFile: URL, sessionID: String) throws -> TranscriptContent {
        let database = try OpenCodeDatabase.open(databaseFile)
        defer { sqlite3_close(database) }
        // One read transaction, so messages OpenCode adds meanwhile cannot appear without their parts.
        try OpenCodeDatabase.execute("BEGIN", in: database)
        defer { try? OpenCodeDatabase.execute("ROLLBACK", in: database) }
        let index = try OpenCodeTranscriptIndex.read(sessionID: sessionID, in: database)
        let messages = try OpenCodeTranscriptMessageReader(in: database)
        defer { messages.close() }
        let partsStatement = try OpenCodeDatabase.prepare(OpenCodeTranscriptParts.query, in: database)
        defer { sqlite3_finalize(partsStatement) }

        var builder = TranscriptBuilder(maximumEntryCount: maximumEntryCount, maximumTextLength: maximumTextLength)
        for messageID in index.messageIDs {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let message = try messages.message(id: messageID) else { return }
                let parts = try OpenCodeTranscriptParts.read(messageID: message.id, with: partsStatement).parts
                append(message, parts: parts, to: &builder)
            }
        }
        if index.hasUndoneMessages { Self.appendUndoneMessagesNote(to: &builder) }
        return builder.build()
    }

    func append(_ message: OpenCodeTranscriptMessage, parts: [[String: Any]], to builder: inout TranscriptBuilder) {
        switch message.role {
        case .user:
            builder.append(.userMessage, text: userText(from: parts), timestamp: message.timestamp)
            if parts.contains(where: { $0["type"] as? String == "compaction" }) {
                builder.appendCompactionNote(timestamp: message.timestamp)
            }
        case .assistant:
            // A compaction's summary replaces the older messages for the model; the note above marks it instead.
            if !message.isCompactionSummary {
                for part in parts { appendAssistantPart(part, timestamp: message.timestamp, to: &builder) }
            }
            if let errorText = message.errorText {
                builder.append(.note, text: errorText, timestamp: message.timestamp)
            }
        }
    }

    static func appendUndoneMessagesNote(to builder: inout TranscriptBuilder) {
        builder.append(.note, text: undoneMessagesNoteText, timestamp: nil)
    }

    /// OpenCode adds synthetic text to a prompt, such as the contents of a file it mentions. An attachment the
    /// prompt mentions already shows as `@file` or `[Image 1]` in its text; others show as a label.
    private func userText(from parts: [[String: Any]]) -> String {
        parts.compactMap { part -> String? in
            switch part["type"] as? String {
            case "text": part["synthetic"] as? Bool == true ? nil : part["text"] as? String
            case "file": part["source"] is [String: Any] ? nil : attachmentLabel(for: part)
            default: nil
            }
        }.joined(separator: "\n\n")
    }

    private func attachmentLabel(for part: [String: Any]) -> String {
        if (part["mime"] as? String)?.hasPrefix("image/") == true { return "[Image]" }
        let fileName = (part["filename"] as? String).flatMap { $0.contains { !$0.isWhitespace } ? $0 : nil }
        return fileName.map { "[File: \($0)]" } ?? "[File]"
    }

    private func appendAssistantPart(_ part: [String: Any], timestamp: Date, to builder: inout TranscriptBuilder) {
        switch part["type"] as? String {
        case "text":
            builder.append(.assistantMessage, text: part["text"] as? String ?? "", timestamp: timestamp)
        case "tool":
            let input = (part["state"] as? [String: Any])?["input"] as? [String: Any] ?? [:]
            builder.append(
                .toolCall,
                text: ToolCallSummary.summary(toolName: part["tool"] as? String ?? "tool", arguments: input),
                timestamp: timestamp
            )
        default:
            break
        }
    }
}
