import Foundation

extension ConversationStore {
    func recoverLostKiroCLIs() {
        let lostPaneProcessIDs = lostKiroPaneProcessIDs()
        guard !lostPaneProcessIDs.isEmpty, let tmuxServer = commandResolver.thisMacTmuxServer() else { return }
        let runningNames = tmuxSessionNamesByHost[.thisMac] ?? []
        let candidates =
            conversations
            .filter { $0.host == .thisMac && $0.provider == .kiro && !runningNames.contains(TmuxSessionName.forConversation($0)) }
            .map { (sessionID: $0.sessionID, sourceFile: $0.sourceFile) }
        guard !candidates.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            var lockProcessIDs: [String: Int32] = [:]
            for candidate in candidates {
                if let lock = KiroSessionLock.heldLock(forSessionFile: candidate.sourceFile) {
                    lockProcessIDs[candidate.sessionID] = lock.processID
                }
            }
            guard !lockProcessIDs.isEmpty else { return }
            let sessionIDs = LostKiroCLIs.sessionIDs(
                lostPaneProcessIDs: lostPaneProcessIDs,
                lockProcessIDsBySessionID: lockProcessIDs,
                tree: .ofRunningProcesses()
            )
            guard !sessionIDs.isEmpty else { return }
            await self?.adoptLostKiroTmuxSessions(sessionIDs, tmuxServer: tmuxServer)
        }
    }

    private func lostKiroPaneProcessIDs() -> [String: Int32] {
        guard thisMacTmuxPaneProcessIDs.keys.contains(where: { $0.hasPrefix(LostKiroCLIs.temporaryNamePrefix) }) else { return [:] }
        let tabTmuxNames = Set(storesOfEveryWindow.flatMap { $0.terminalSessions.compactMap(\.tmuxSessionName) })
        return LostKiroCLIs.lostPaneProcessIDs(in: thisMacTmuxPaneProcessIDs, tabTmuxNames: tabTmuxNames)
    }

    private func adoptLostKiroTmuxSessions(_ sessionIDsByTmuxName: [String: String], tmuxServer: ThisMacTmuxServer) {
        let lostPaneProcessIDs = lostKiroPaneProcessIDs()
        for (temporaryName, sessionID) in sessionIDsByTmuxName {
            let sessionName = TmuxSessionName.forSession(provider: .kiro, sessionID: sessionID)
            guard let paneProcessID = lostPaneProcessIDs[temporaryName],
                tmuxSessionNamesByHost[.thisMac]?.contains(sessionName) != true
            else { continue }
            tmuxCommandQueues.runAfterEarlierCommands(on: .thisMac) { tmuxServer.renameSession(from: temporaryName, to: sessionName) }
            tmuxSessionNamesByHost[.thisMac, default: []].remove(temporaryName)
            tmuxSessionNamesByHost[.thisMac, default: []].insert(sessionName)
            thisMacTmuxPaneProcessIDs[temporaryName] = nil
            thisMacTmuxPaneProcessIDs[sessionName] = paneProcessID
        }
    }
}
