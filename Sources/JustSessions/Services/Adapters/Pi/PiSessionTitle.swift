import Foundation

/// A Pi session's title: the name given with `/name` or `--name`, or else the first thing the user typed.
enum PiSessionTitle {
    static let maximumTailByteCount = 262_144
    /// The first prompt follows the header and the system message, which lists every tool and can be long.
    static let maximumLeadingByteCount = 1_048_576

    /// The name from the last `session_info` line near the end of the file.
    static func latestName(in file: URL) -> String? {
        latestName(amongLines: JSONLinesReader.trailingLines(in: file, maximumByteCount: maximumTailByteCount))
    }

    /// `lines` are oldest first, as they are in the file.
    static func latestName(amongLines lines: [Data]) -> String? {
        for line in lines.reversed() {
            guard let record = ConversationMetadata.object(from: line),
                  record["type"] as? String == "session_info",
                  let name = (record["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            return name
        }
        return nil
    }

    static func firstUserPrompt(in file: URL) -> String? {
        firstUserPrompt(amongLines: JSONLinesReader.leadingLines(in: file, maximumByteCount: maximumLeadingByteCount))
    }

    /// The text of the first user message; its content is a string or a list of text and image parts.
    static func firstUserPrompt(amongLines lines: [Data]) -> String? {
        for line in lines {
            guard let record = ConversationMetadata.object(from: line),
                  record["type"] as? String == "message",
                  let message = record["message"] as? [String: Any],
                  message["role"] as? String == "user" else { continue }
            let text: String? = if let content = message["content"] as? String {
                content
            } else if let parts = message["content"] as? [[String: Any]] {
                parts.first { $0["type"] as? String == "text" }?["text"] as? String
            } else {
                nil
            }
            if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        }
        return nil
    }
}
