/// Which session each lost Kiro CLI on this Mac runs: a tab that closed before it linked to its session left its CLI
/// running in tmux under the tab's temporary name (`TmuxSessionName.unique(for:)`), as every Kiro tab did before Kiro
/// CLI 2.16's sessions were listed. Kiro's lock on a session names a process of that CLI
/// (`KiroSessionLock`), so the pane it runs under tells which tmux session runs it.
enum LostKiroCLIs {
    /// How far above a lock's process its tmux pane may be: Kiro CLI 2.16.2's V2 lock names the process three below
    /// the pane's, and 2.34.0's V3 lock the one two below.
    static let maximumDepth = 12

    static var temporaryNamePrefix: String { TmuxSessionName.prefix + ConversationProvider.kiro.executableName + "-new-" }

    static func lostPaneProcessIDs(in paneProcessIDs: [String: Int32], tabTmuxNames: Set<String>) -> [String: Int32] {
        paneProcessIDs.filter { $0.key.hasPrefix(temporaryNamePrefix) && !tabTmuxNames.contains($0.key) }
    }

    static func sessionIDs(
        lostPaneProcessIDs: [String: Int32],
        lockProcessIDsBySessionID: [String: Int32],
        tree: ProcessTree
    ) -> [String: String] {
        let tmuxNamesByPaneProcessID = Dictionary(lostPaneProcessIDs.map { ($0.value, $0.key) }, uniquingKeysWith: { _, _ in "" })
        var sessionIDsByTmuxName: [String: Set<String>] = [:]
        for (sessionID, lockProcessID) in lockProcessIDsBySessionID {
            var processID = lockProcessID
            for _ in 0...maximumDepth {
                if let tmuxName = tmuxNamesByPaneProcessID[processID], !tmuxName.isEmpty {
                    sessionIDsByTmuxName[tmuxName, default: []].insert(sessionID)
                    break
                }
                guard let parentProcessID = tree.parentProcessIDs[processID], parentProcessID > 1, parentProcessID != processID
                else { break }
                processID = parentProcessID
            }
        }
        var matches: [String: String] = [:]
        for (tmuxName, sessionIDs) in sessionIDsByTmuxName where sessionIDs.count == 1 { matches[tmuxName] = sessionIDs.first }
        let tmuxNameCountsBySessionID = Dictionary(matches.map { ($0.value, 1) }, uniquingKeysWith: +)
        return matches.filter { tmuxNameCountsBySessionID[$0.value] == 1 }
    }
}
