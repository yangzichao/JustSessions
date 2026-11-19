import Foundation

enum ClaudeUserPromptText {
    static func text(ofRecord record: [String: Any]) -> String? {
        guard record["type"] as? String == "user", let message = record["message"] as? [String: Any] else { return nil }
        if let text = message["content"] as? String { return text }
        guard let parts = message["content"] as? [[String: Any]] else { return nil }
        return parts.first { $0["type"] as? String == "text" }?["text"] as? String
    }
}
