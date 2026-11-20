import Foundation

struct CLIActivityReader: Sendable {
    let claudeRegistry: ClaudeLiveSessionRegistry
    let codexTurnTracker: CodexRolloutTurnTracker
    let liveSessionReporting: LiveSessionReporting?
    var codexWaitReader: CodexAppServerWaitReader? = nil
    var kiroTurnMarkers = KiroTurnMarkers()

    func activities(for probes: [CLIActivityProbe]) -> [CLIActivity?] {
        var processTree: ProcessTree?
        let codexThreadsWaitingOnYou =
            codexWaitReader?.threadsWaitingOnYou(
                among: Set(
                    probes.compactMap { probe in
                        probe.provider == .codex ? probe.sessionID : nil
                    })) ?? []
        let activities = probes.map { probe in
            activity(for: probe, codexThreadsWaitingOnYou: codexThreadsWaitingOnYou, processTree: &processTree)
        }
        codexTurnTracker.stopFollowingFiles(
            otherThan: Set(
                probes.compactMap { probe in
                    probe.provider == .codex ? probe.sessionFile?.path : nil
                }))
        return activities
    }

    /// A turn that started before the CLI did was left open by an earlier CLI that ended in the middle of it. Only a
    /// turn of this CLI's waits on you, as Codex's background server may still hold a thread whose CLI ended.
    static func codexActivity(turnState: CodexTurnState?, cliStartedAt: Date?, isWaitingOnYou: Bool = false) -> CLIActivity? {
        switch turnState {
        case nil:
            return nil
        case .betweenTurns:
            return .idle
        case .inTurn(let turnStartedAt):
            if isLeftOpenByAnEarlierCLI(turnStartedAt: turnStartedAt, cliStartedAt: cliStartedAt) { return .idle }
            return isWaitingOnYou ? .needsInput(reason: nil) : .working
        }
    }

    static func antigravityActivity(turnState: AntigravityTurnState?, cliStartedAt: Date?) -> CLIActivity? {
        switch turnState {
        case nil:
            return nil
        case .betweenTurns:
            return .idle
        case .inTurn(let turnStartedAt, let isWaitingForApproval):
            if isLeftOpenByAnEarlierCLI(turnStartedAt: turnStartedAt, cliStartedAt: cliStartedAt) { return .idle }
            return isWaitingForApproval ? .needsInput(reason: nil) : .working
        }
    }

    private static func isLeftOpenByAnEarlierCLI(turnStartedAt: Date?, cliStartedAt: Date?) -> Bool {
        guard let turnStartedAt, let cliStartedAt else { return false }
        return turnStartedAt < cliStartedAt
    }

    private func activity(
        for probe: CLIActivityProbe,
        codexThreadsWaitingOnYou: Set<String>,
        processTree: inout ProcessTree?
    ) -> CLIActivity? {
        switch probe.provider {
        case .claude:
            if let activity = remoteActivity(of: probe) { return activity }
            guard probe.processID > 0 else { return nil }
            if let record = claudeRegistry.record(forProcessID: probe.processID) { return record.activity }
            // The registry names the real CLI's process, which a wrapper script starts as its child.
            let tree = processTree ?? .ofRunningProcesses()
            processTree = tree
            return claudeRegistry.firstRecord(amongProcessIDs: tree.breadthFirstProcessIDs(rootedAt: probe.processID))?.activity
        case .codex:
            if let activity = probe.terminalTitle.flatMap(CodexTitleActivity.activity(inTerminalTitle:)) { return activity }
            guard let sessionFile = probe.sessionFile else { return nil }
            return Self.codexActivity(
                turnState: codexTurnTracker.turnState(ofRolloutFile: sessionFile),
                cliStartedAt: RunningProcessInfo.startDate(of: probe.processID),
                isWaitingOnYou: probe.sessionID.map(codexThreadsWaitingOnYou.contains) ?? false
            )
        case .antigravity:
            if let activity = remoteActivity(of: probe) { return activity }
            guard let sessionFile = probe.sessionFile else { return nil }
            return Self.antigravityActivity(
                turnState: AntigravityTurnStateReader.turnState(ofConversationDatabase: sessionFile),
                cliStartedAt: RunningProcessInfo.startDate(of: probe.processID)
            )
        case .opencode, .pi:
            if let activity = remoteActivity(of: probe) { return activity }
            return liveSessionReporting?.report(forProcessID: probe.processID)?.activity
        case .kiro:
            if let activity = remoteActivity(of: probe) { return activity }
            guard probe.processID > 0, let processIDsWithATurn = kiroTurnMarkers.processIDsWithATurn() else { return nil }
            // A marker names Kiro's TUI, below the `kiro-cli` the tab started.
            let tree = processTree ?? .ofRunningProcesses()
            processTree = tree
            return KiroTurnMarkers.activity(
                processIDsWithATurn: processIDsWithATurn,
                cliProcessIDs: tree.breadthFirstProcessIDs(rootedAt: probe.processID)
            )
        }
    }

    private func remoteActivity(of probe: CLIActivityProbe) -> CLIActivity? {
        probe.terminalTitle.flatMap { RemoteCLIActivityTitle.activity(inTerminalTitle: $0, of: probe.provider) }
    }
}
