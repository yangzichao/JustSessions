import Foundation

/// What the user typed in a Claude Code `user` record. Sent as plain text, the message's content is a string; sent
/// with images or pasted files, it is a list of parts, and the prompt is its first `text` part. A record whose content
/// is only tool results holds nothing the user typed.
enum ClaudeUserPromptText {
    static func text(ofRecord record: [String: Any]) -> String? {
        guard record["type"] as? String == "user", let message = record["message"] as? [String: Any] else { return nil }
        if let text = message["content"] as? String { return text }
        guard let parts = message["content"] as? [[String: Any]] else { return nil }
        return parts.first { $0["type"] as? String == "text" }?["text"] as? String
    }
}
