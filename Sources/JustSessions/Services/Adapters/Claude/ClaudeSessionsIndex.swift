import Foundation

struct ClaudeSessionsIndex {
    struct Entry {
        let projectPath: String?
        let customTitle: String?
        let firstPrompt: String?
        let modifiedAt: Date?
        let isSidechain: Bool

        init(record: [String: Any]) {
            projectPath = record["projectPath"] as? String
            customTitle = record["customTitle"] as? String
            firstPrompt = record["firstPrompt"] as? String
            modifiedAt = ConversationMetadata.date(record["modified"])
            isSidechain = record["isSidechain"] as? Bool == true
        }
    }

    let originalProjectPath: String?
    private let entriesBySessionID: [String: Entry]

    init(projectDirectory: URL) {
        let data = try? Data(contentsOf: projectDirectory.appendingPathComponent("sessions-index.json"))
        self.init(jsonData: data ?? Data())
    }

    init(jsonData: Data) {
        let root = ConversationMetadata.object(from: jsonData) ?? [:]
        let records = root["entries"] as? [[String: Any]] ?? []
        originalProjectPath = root["originalPath"] as? String
        entriesBySessionID = Dictionary(
            records.compactMap { record in
                (record["sessionId"] as? String).map { sessionID in (sessionID, Entry(record: record)) }
            },
            uniquingKeysWith: { _, laterEntry in laterEntry }
        )
    }

    func entry(forSessionID sessionID: String) -> Entry? {
        entriesBySessionID[sessionID]
    }
}
