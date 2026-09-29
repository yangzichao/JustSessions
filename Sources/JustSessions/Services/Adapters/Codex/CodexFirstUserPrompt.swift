import Foundation

/// Finds the first thing the user typed in a Codex rollout file, which titles a session the index has no name for.
enum CodexFirstUserPrompt {
    static let maximumByteCount = 262_144
    static let maximumLineCount = 80
    /// User messages that start with one of these hold context Codex adds itself, not something the user typed.
    static let injectedContextPrefixes = ["# AGENTS.md", "<environment_context>", "<user_instructions>"]

    static func find(in file: URL) -> String? {
        find(amongLines: JSONLinesReader.leadingLines(in: file, maximumByteCount: maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file. Returns the text trimmed.
    static func find(amongLines lines: [Data]) -> String? {
        for line in lines.prefix(maximumLineCount) {
            guard let record = ConversationMetadata.object(from: line),
                  record["type"] as? String == "response_item",
                  let payload = record["payload"] as? [String: Any],
                  payload["type"] as? String == "message",
                  payload["role"] as? String == "user",
                  let content = payload["content"] as? [[String: Any]] else { continue }
            for part in content where part["type"] as? String == "input_text" {
                guard let text = (part["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty,
                      !injectedContextPrefixes.contains(where: text.hasPrefix) else { continue }
                return text
            }
        }
        return nil
    }
}
