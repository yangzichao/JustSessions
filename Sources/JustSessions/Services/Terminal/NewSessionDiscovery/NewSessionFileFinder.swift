import Foundation

struct NewSessionFileFinder: Sendable {
    var claudeTranscripts = ClaudeSessionFileLocator()
    var claudeRegistry = ClaudeLiveSessionRegistry()
    var openFileReader = ProcessOpenFileReader()

    func sessionFiles(for tabs: [WaitingNewSessionTab], processTree: ProcessTree) -> [UUID: NewSessionFile] {
        var sessionFiles: [UUID: NewSessionFile] = [:]
        var processIDsOfTabsNeedingOpenFiles: [UUID: [Int32]] = [:]
        for tab in tabs {
            if let preassignedSessionID = tab.preassignedSessionID,
                let transcript = claudeTranscripts.transcriptFile(forSessionID: preassignedSessionID)
            {
                sessionFiles[tab.terminalID] = Self.sessionFile(preassignedSessionID, at: transcript)
                continue
            }
            guard let cliProcessID = tab.runningCLIProcessID else { continue }
            let processIDs = processTree.breadthFirstProcessIDs(rootedAt: cliProcessID)
            switch tab.provider {
            case .claude:
                if let record = claudeRegistry.firstRecord(amongProcessIDs: processIDs),
                    tab.couldBeOwnSession(record.sessionID),
                    let transcript = claudeTranscripts.transcriptFile(forSessionID: record.sessionID)
                {
                    sessionFiles[tab.terminalID] = Self.sessionFile(record.sessionID, at: transcript)
                }
            case .codex, .antigravity:
                processIDsOfTabsNeedingOpenFiles[tab.terminalID] = processIDs
            case .kiro, .opencode, .pi:
                continue
            }
        }
        guard !processIDsOfTabsNeedingOpenFiles.isEmpty else { return sessionFiles }

        let openFilePaths = openFileReader.openFilePaths(
            ofProcessIDs: Array(Set(processIDsOfTabsNeedingOpenFiles.values.joined()))
        )
        for tab in tabs {
            guard let processIDs = processIDsOfTabsNeedingOpenFiles[tab.terminalID] else { continue }
            let openSessionFile = processIDs.lazy
                .flatMap { openFilePaths[$0] ?? [] }
                .compactMap { path -> NewSessionFile? in
                    guard let sessionID = OpenSessionFileName.sessionID(inOpenFilePath: path, provider: tab.provider),
                        tab.couldBeOwnSession(sessionID)
                    else { return nil }
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
