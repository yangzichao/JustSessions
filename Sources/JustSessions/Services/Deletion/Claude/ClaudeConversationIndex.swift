import Foundation

enum ClaudeConversationIndex {
    static func remove(sessionIDs: Set<String>, in projectDirectory: URL) throws {
        let indexFile = projectDirectory.appendingPathComponent("sessions-index.json")
        guard FileManager.default.fileExists(atPath: indexFile.path) else { return }
        let data = try Data(contentsOf: indexFile)
        guard var index = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = index["entries"] as? [[String: Any]] else { return }
        let remainingEntries = entries.filter { entry in
            guard let sessionID = entry["sessionId"] as? String else { return true }
            return !sessionIDs.contains(sessionID)
        }
        guard remainingEntries.count != entries.count else { return }
        index["entries"] = remainingEntries
        try JSONSerialization.data(withJSONObject: index, options: [.prettyPrinted, .sortedKeys])
            .write(to: indexFile, options: .atomic)
    }
}
