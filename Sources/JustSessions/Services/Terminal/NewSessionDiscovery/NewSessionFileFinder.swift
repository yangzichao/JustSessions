import Foundation

/// Finds the session file each waiting "New session" or "Branch" tab is writing, from facts rather than
/// guesses: the session id the app asked Claude Code to use, Claude Code's per-process registry, and the
/// files the CLI holds open. Process lookups cover the tab's whole process tree, so a CLI that an install's
/// wrapper script starts as a child process still counts.
struct NewSessionFileFinder: Sendable {
    var claudeTranscripts = ClaudeSessionFileLocator()
    var claudeRegistry = ClaudeLiveSessionRegistry()
    var openFileReader = ProcessOpenFileReader()

    func sessionFiles(for tabs: [WaitingNewSessionTab], processTree: ProcessTree) -> [UUID: NewSessionFile] {
        var sessionFiles: [UUID: NewSessionFile] = [:]
        var processIDsOfTabsNeedingOpenFiles: [UUID: [Int32]] = [:]
        for tab in tabs {
            if let preassignedSessionID = tab.preassignedSessionID,
               let transcript = claudeTranscripts.transcriptFile(forSessionID: preassignedSessionID) {
                sessionFiles[tab.terminalID] = Self.sessionFile(preassignedSessionID, at: transcript)
                continue
            }
            guard tab.isRunning, tab.processID > 0 else { continue }
            let processIDs = processTree.processIDs(rootedAt: tab.processID)
            switch tab.provider {
            case .claude:
                // For tabs launched without a preassigned id: before the `--help` check finished, or on an
                // install without the flag.
                if let record = claudeRegistry.firstRecord(amongProcessIDs: processIDs),
                   tab.couldBeOwnSession(record.sessionID),
                   let transcript = claudeTranscripts.transcriptFile(forSessionID: record.sessionID) {
                    sessionFiles[tab.terminalID] = Self.sessionFile(record.sessionID, at: transcript)
                }
            case .codex, .antigravity:
                processIDsOfTabsNeedingOpenFiles[tab.terminalID] = processIDs
            }
        }
        guard !processIDsOfTabsNeedingOpenFiles.isEmpty else { return sessionFiles }

        let openFilePaths = openFileReader.openFilePaths(
            ofProcessIDs: Array(Set(processIDsOfTabsNeedingOpenFiles.values.joined()))
        )
        for tab in tabs {
            guard let processIDs = processIDsOfTabsNeedingOpenFiles[tab.terminalID] else { continue }
            // The tab's own process first, then the processes it started.
            let openSessionFile = processIDs.lazy
                .flatMap { openFilePaths[$0] ?? [] }
                .compactMap { path -> NewSessionFile? in
                    guard let sessionID = OpenSessionFileName.sessionID(inOpenFilePath: path, provider: tab.provider),
                          tab.couldBeOwnSession(sessionID) else { return nil }
                    return Self.sessionFile(sessionID, at: URL(fileURLWithPath: path))
                }
                .first
            sessionFiles[tab.terminalID] = openSessionFile
        }
        return sessionFiles
    }

    private static func sessionFile(_ sessionID: String, at file: URL) -> NewSessionFile {
        NewSessionFile(
            sessionID: sessionID,
            file: file,
            lastModified: max(
                ConversationMetadata.fileModificationDate(file),
                ConversationMetadata.fileModificationDate(URL(fileURLWithPath: file.path + "-wal"))
            )
        )
    }
}
