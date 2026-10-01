import Foundation

/// Where Pi saves sessions, and the session files in it.
enum PiSessionsDirectory {
    /// Pi's own order: `PI_CODING_AGENT_SESSION_DIR`, then `sessionDir` in the agent folder's `settings.json`, then
    /// `sessions` in the agent folder (`PI_CODING_AGENT_DIR`, or `~/.pi/agent`).
    static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        if let configured = environment["PI_CODING_AGENT_SESSION_DIR"], !configured.isEmpty {
            return URL(fileURLWithPath: expandingTilde(configured, homeDirectory: homeDirectory))
        }
        let agentDirectory = URL(fileURLWithPath: expandingTilde(
            environment["PI_CODING_AGENT_DIR"].flatMap { $0.isEmpty ? nil : $0 } ?? "~/.pi/agent",
            homeDirectory: homeDirectory
        ))
        if let configured = settingsSessionDirectory(in: agentDirectory) {
            return URL(fileURLWithPath: expandingTilde(configured, homeDirectory: homeDirectory))
        }
        return agentDirectory.appendingPathComponent("sessions")
    }

    /// The `.jsonl` files directly in the folder, and in its per-project folders.
    static func sessionFiles(in sessionsDirectory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.flatMap { entry -> [URL] in
            if entry.pathExtension == "jsonl" { return [entry] }
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return [] }
            let projectFiles = (try? fileManager.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return projectFiles.filter { $0.pathExtension == "jsonl" }
        }
    }

    private static func settingsSessionDirectory(in agentDirectory: URL) -> String? {
        guard let data = try? Data(contentsOf: agentDirectory.appendingPathComponent("settings.json")),
              let settings = ConversationMetadata.object(from: data),
              let sessionDirectory = settings["sessionDir"] as? String,
              !sessionDirectory.isEmpty else { return nil }
        return sessionDirectory
    }

    private static func expandingTilde(_ path: String, homeDirectory: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        return homeDirectory + path.dropFirst()
    }
}
