import Foundation

/// Cheaply checks whether Claude Code has written the transcript for a session yet.
/// Claude Code only creates `projects/<project>/<sessionId>.jsonl` once the first message is sent.
struct ClaudeSessionFileLocator: Sendable {
    let projectsDirectory: URL

    init(configurationDirectory: URL = ClaudeAdapter().configurationDirectory) {
        self.projectsDirectory = configurationDirectory.appendingPathComponent("projects")
    }

    func transcriptExists(forSessionID sessionID: String) -> Bool {
        guard ConversationMetadata.isValidSessionID(sessionID),
              let projectDirectories = try? FileManager.default.contentsOfDirectory(
                  at: projectsDirectory,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else { return false }
        return projectDirectories.contains {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("\(sessionID).jsonl").path)
        }
    }
}
