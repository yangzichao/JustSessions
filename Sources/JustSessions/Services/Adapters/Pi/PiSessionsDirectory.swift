import Foundation

/// Where Pi saves sessions, and the session files in it.
enum PiSessionsDirectory {
    /// Pi's own order: `PI_CODING_AGENT_SESSION_DIR`, then `sessionDir` in the agent folder's `settings.json`, then
    /// `sessions` in the agent folder (`PI_CODING_AGENT_DIR`, or `~/.pi/agent`).
    static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        URL(fileURLWithPath: standardPath(
            environment: environment,
            homeDirectory: homeDirectory,
            settingsData: { try? Data(contentsOf: $0) }
        ))
    }

    /// The folder's path, which is relative when a setting gives a relative one. `settingsData` reads the agent
    /// folder's `settings.json`, so an SSH host's folder is found with the file from the host.
    static func standardPath(
        environment: [String: String],
        homeDirectory: String,
        settingsData: (URL) -> Data?
    ) -> String {
        if let configured = environment["PI_CODING_AGENT_SESSION_DIR"], !configured.isEmpty {
            return expandingTilde(configured, homeDirectory: homeDirectory)
        }
        let agentDirectory = expandingTilde(
            environment["PI_CODING_AGENT_DIR"].flatMap { $0.isEmpty ? nil : $0 } ?? "~/.pi/agent",
            homeDirectory: homeDirectory
        )
        if let configured = settingsSessionDirectory(in: URL(fileURLWithPath: agentDirectory), settingsData: settingsData) {
            return expandingTilde(configured, homeDirectory: homeDirectory)
        }
        return (agentDirectory as NSString).appendingPathComponent("sessions")
    }

    /// The `.jsonl` files directly in the folder, and in its per-project folders. Pi saves sessions as plain files, so
    /// a symbolic link or a pipe with a session's name is left out. An SSH host's sessions are copied with their links
    /// and pipes as they are, and reading one would show a file from elsewhere on this Mac or wait forever.
    static func sessionFiles(in sessionsDirectory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.flatMap { entry -> [URL] in
            if entry.pathExtension == "jsonl" { return isRegularFile(entry) ? [entry] : [] }
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return [] }
            let projectFiles = (try? fileManager.contentsOfDirectory(
                at: entry,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return projectFiles.filter { $0.pathExtension == "jsonl" && isRegularFile($0) }
        }
    }

    /// Describes the item itself, so a symbolic link to a file is not a regular file.
    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }

    private static func settingsSessionDirectory(in agentDirectory: URL, settingsData: (URL) -> Data?) -> String? {
        guard let data = settingsData(agentDirectory.appendingPathComponent("settings.json")),
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
