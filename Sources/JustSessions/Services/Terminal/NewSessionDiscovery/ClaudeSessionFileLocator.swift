import Foundation

/// Finds the transcript Claude Code writes for a session, `projects/<project>/<sessionId>.jsonl`, without
/// knowing which project directory name Claude Code picked. It may not exist until the session starts.
struct ClaudeSessionFileLocator: Sendable {
    let projectsDirectory: URL

    init(configurationDirectory: URL = ClaudeAdapter().configurationDirectory) {
        self.projectsDirectory = configurationDirectory.appendingPathComponent("projects")
    }

    func transcriptFile(forSessionID sessionID: String) -> URL? {
        guard ConversationMetadata.isValidSessionID(sessionID),
              let projectDirectories = try? FileManager.default.contentsOfDirectory(
                  at: projectsDirectory,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else { return nil }
        return projectDirectories
            .map { $0.appendingPathComponent("\(sessionID).jsonl") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
