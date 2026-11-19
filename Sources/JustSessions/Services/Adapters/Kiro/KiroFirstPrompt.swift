import Foundation

enum KiroFirstPrompt {
    static let maximumByteCount = 262_144

    static func find(in file: URL) -> String? {
        find(amongLines: JSONLinesReader.leadingLines(in: file, maximumByteCount: maximumByteCount))
    }

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
