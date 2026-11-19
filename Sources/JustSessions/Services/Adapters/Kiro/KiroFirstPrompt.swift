import Foundation

/// Finds the first thing the user typed in a Kiro CLI session's `<id>.jsonl`, which titles a session Kiro has not
/// named. Each line is `{"version":"v1","kind":…,"data":…}`; a `Prompt` line's `data.content` is a list of parts,
/// and a `text` part's `data` is its text. A V3 session's `messages.jsonl` has `{"payload":{"type":"user","content":…}}`
/// events instead, the content a string.
enum KiroFirstPrompt {
    static let maximumByteCount = 262_144

    static func find(in file: URL) -> String? {
        find(amongLines: JSONLinesReader.leadingLines(in: file, maximumByteCount: maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file. Returns the text trimmed.
    static func find(amongLines lines: [Data]) -> String? {
        for line in lines {
            guard let record = ConversationMetadata.object(from: line) else { continue }
            if let payload = record["payload"] as? [String: Any] {
                guard payload["type"] as? String == "user",
                    let text = (payload["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty
                else { continue }
                return text
            }
            guard record["kind"] as? String == "Prompt",
                let data = record["data"] as? [String: Any],
                let content = data["content"] as? [[String: Any]]
            else { continue }
            for part in content where part["kind"] as? String == "text" {
                guard let text = (part["data"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !text.isEmpty
                else { continue }
                return text
            }
        }
        return nil
    }
}
