import Foundation

/// Tells what running CLIs are doing. Claude Code says so in its live process registry, which on an SSH host reaches
/// the tab through a relay; Codex in its terminal title, on this Mac and on an SSH host, and otherwise its session
/// file shows whether a turn is under way, and Codex's background server whether it waits for you; an Antigravity
/// conversation database shows both, and on an SSH host reaches the tab through a relay. Pi and OpenCode say so through the extension the app starts them with, which on
/// an SSH host tells the tab through its title. Kiro CLI marks its turns in a folder (`KiroTurnMarkers`), which on an
/// SSH host reaches the tab through a relay too. CLIs whose process or file is not known yet give nil.
struct CLIActivityReader: Sendable {
    let claudeRegistry: ClaudeLiveSessionRegistry
    let codexTurnTracker: CodexRolloutTurnTracker
    /// Nil when the app starts Pi and OpenCode without its extension, as in tests and `swift run`.
    let liveSessionReporting: LiveSessionReporting?
    /// Nil where the app leaves Codex's background server alone, as in tests and `swift run`.
    var codexWaitReader: CodexAppServerWaitReader? = nil
    var kiroTurnMarkers = KiroTurnMarkers()

    /// One activity per probe, in order. Stops following the Codex files of CLIs that are no longer probed.
    func activities(for probes: [CLIActivityProbe]) -> [CLIActivity?] {
        // Read at most once, and only when a Claude Code install turns out to be a wrapper script.
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

    /// As for Codex, a turn that started before the CLI did was left open by an earlier CLI.
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

    /// Without both times, a turn under way is taken at its word.
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
            // On an SSH host, its record there, which the relay puts in the title; see `RemoteCLIActivityTitle`.
            if let activity = remoteActivity(of: probe) { return activity }
            guard probe.processID > 0 else { return nil }
            if let record = claudeRegistry.record(forProcessID: probe.processID) { return record.activity }
            // The registry names the real CLI's process, which a wrapper script starts as its child.
            let tree = processTree ?? .ofRunningProcesses()
            processTree = tree
            return claudeRegistry.firstRecord(amongProcessIDs: tree.processIDs(rootedAt: probe.processID))?.activity
        case .codex:
            // Codex's own word, when its title has one; see `CodexTitleActivity`. A Codex too old to give it, or one
            // that hasn't yet, is read from its session file.
            if let activity = probe.terminalTitle.flatMap(CodexTitleActivity.activity(inTerminalTitle:)) { return activity }
            guard let sessionFile = probe.sessionFile else { return nil }
            return Self.codexActivity(
                turnState: codexTurnTracker.turnState(ofRolloutFile: sessionFile),
                cliStartedAt: RunningProcessInfo.startDate(of: probe.processID),
                isWaitingOnYou: probe.sessionID.map(codexThreadsWaitingOnYou.contains) ?? false
            )
        case .antigravity:
            // On an SSH host, the relay puts it in the title.
            if let activity = remoteActivity(of: probe) { return activity }
            guard let sessionFile = probe.sessionFile else { return nil }
            return Self.antigravityActivity(
                turnState: AntigravityTurnStateReader.turnState(ofConversationDatabase: sessionFile),
                cliStartedAt: RunningProcessInfo.startDate(of: probe.processID)
            )
        case .opencode, .pi:
            // On an SSH host, the extension puts it in the title.
            if let activity = remoteActivity(of: probe) { return activity }
            return liveSessionReporting?.report(forProcessID: probe.processID)?.activity
        case .kiro:
            // On an SSH host, the relay puts it in the title.
            if let activity = remoteActivity(of: probe) { return activity }
            guard probe.processID > 0, let processIDsWithATurn = kiroTurnMarkers.processIDsWithATurn() else { return nil }
            // A marker names Kiro's TUI, below the `kiro-cli` the tab started.
            let tree = processTree ?? .ofRunningProcesses()
            processTree = tree
            return KiroTurnMarkers.activity(
                processIDsWithATurn: processIDsWithATurn,
                cliProcessIDs: tree.processIDs(rootedAt: probe.processID)
            )
        }
    }

    private func remoteActivity(of probe: CLIActivityProbe) -> CLIActivity? {
        probe.terminalTitle.flatMap { RemoteCLIActivityTitle.activity(inTerminalTitle: $0, of: probe.provider) }
    }
}
