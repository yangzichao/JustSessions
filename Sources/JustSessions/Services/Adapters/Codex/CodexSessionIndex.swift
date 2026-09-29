import Foundation

/// Codex's `session_index.jsonl`: one line per entry, holding a session's thread name and when it was last updated.
struct CodexSessionIndex {
    struct Entry {
        let threadName: String
        let updatedAt: Date?
    }

    private let entriesBySessionID: [String: Entry]

    init(codexDirectory: URL) {
        let text = try? String(contentsOf: codexDirectory.appendingPathComponent("session_index.jsonl"), encoding: .utf8)
        self.init(text: text ?? "")
    }

    /// When a session has more than one line, the last one wins.
    init(text: String) {
        var entriesBySessionID: [String: Entry] = [:]
        for line in text.split(separator: "\n") {
            guard let record = ConversationMetadata.object(from: Data(line.utf8)),
                  let sessionID = record["id"] as? String,
                  let threadName = record["thread_name"] as? String else { continue }
            entriesBySessionID[sessionID] = Entry(
                threadName: threadName,
                updatedAt: ConversationMetadata.date(record["updated_at"])
            )
        }
        self.entriesBySessionID = entriesBySessionID
    }

    func entry(forSessionID sessionID: String) -> Entry? {
        entriesBySessionID[sessionID]
    }
}
