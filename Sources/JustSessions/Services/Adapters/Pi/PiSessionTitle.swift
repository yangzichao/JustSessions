import Foundation

enum PiSessionTitle {
    static let maximumTailByteCount = 262_144
    /// The first prompt follows the header and the system message, which lists every tool and can be long.
    static let maximumLeadingByteCount = 1_048_576

    static func latestName(amongLines lines: [Data]) -> String? {
        for line in lines.reversed() {
            guard let record = ConversationMetadata.object(from: line),
                record["type"] as? String == "session_info",
                let name = (record["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else { continue }
            return name
        }
        return nil
    }

    static func firstUserPrompt(in file: URL) -> String? {
        var prompt: String?
        JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: maximumLeadingByteCount) { line in
            prompt = userPrompt(in: line)
            return prompt == nil
        }
        return prompt
    }

    static func firstUserPrompt(amongLines lines: [Data]) -> String? {
        lines.lazy.compactMap(userPrompt(in:)).first
    }

    static func latestUserPrompt(in file: URL) -> String? {
        latestUserPrompt(amongLines: JSONLinesReader.trailingLines(in: file, maximumByteCount: maximumTailByteCount))
    }

    static func latestUserPrompt(amongLines lines: [Data]) -> String? {
        lines.reversed().lazy.compactMap(userPrompt(in:)).first
    }

    private static func userPrompt(in line: Data) -> String? {
        guard let record = ConversationMetadata.object(from: line),
            record["type"] as? String == "message",
            let message = record["message"] as? [String: Any],
            message["role"] as? String == "user"
        else { return nil }
        let text: String? =
            if let content = message["content"] as? String {
                content
            } else if let parts = message["content"] as? [[String: Any]] {
                parts.first { $0["type"] as? String == "text" }?["text"] as? String
            } else {
                nil
            }
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
