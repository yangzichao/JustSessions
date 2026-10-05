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

    init(text: String) {
        self.init(lines: text.split(separator: "\n").map { Data($0.utf8) })
    }

    /// When a session has more than one line, the last one wins.
    init(lines: [Data]) {
        var entriesBySessionID: [String: Entry] = [:]
        for line in lines {
            guard let record = ConversationMetadata.object(from: line),
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
