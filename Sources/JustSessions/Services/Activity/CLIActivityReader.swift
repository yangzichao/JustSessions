import Foundation

/// Tells what CLIs running on this Mac are doing. Claude Code says so in its live process registry; a Codex session
/// file shows whether a turn is under way; Pi and OpenCode say so through the extension the app starts them with.
/// Other CLIs, and CLIs whose process or file is not known yet, give nil.
struct CLIActivityReader: Sendable {
    let claudeRegistry: ClaudeLiveSessionRegistry
    let codexTurnTracker: CodexRolloutTurnTracker
    /// Nil when the app starts Pi and OpenCode without its extension, as in tests and `swift run`.
    let liveSessionReporting: LiveSessionReporting?

    /// One activity per probe, in order. Stops following the Codex files of CLIs that are no longer probed.
    func activities(for probes: [CLIActivityProbe]) -> [CLIActivity?] {
        // Read at most once, and only when a Claude Code install turns out to be a wrapper script.
        var processTree: ProcessTree?
        let activities = probes.map { activity(for: $0, processTree: &processTree) }
        codexTurnTracker.stopFollowingFiles(otherThan: Set(probes.compactMap { probe in
            probe.provider == .codex ? probe.sessionFile?.path : nil
        }))
        return activities
    }

    /// A turn that started before the CLI did was left open by an earlier CLI that ended in the middle of it.
    static func codexActivity(turnState: CodexTurnState?, cliStartedAt: Date?) -> CLIActivity? {
        switch turnState {
        case nil:
            return nil
        case .betweenTurns:
            return .idle
        case .inTurn(let turnStartedAt):
            if let turnStartedAt, let cliStartedAt, turnStartedAt < cliStartedAt { return .idle }
            return .working
        }
    }

    private func activity(for probe: CLIActivityProbe, processTree: inout ProcessTree?) -> CLIActivity? {
        switch probe.provider {
        case .claude:
            guard probe.processID > 0 else { return nil }
            if let record = claudeRegistry.record(forProcessID: probe.processID) { return record.activity }
            // The registry names the real CLI's process, which a wrapper script starts as its child.
            let tree = processTree ?? .ofRunningProcesses()
            processTree = tree
            return claudeRegistry.firstRecord(amongProcessIDs: tree.processIDs(rootedAt: probe.processID))?.activity
        case .codex:
            guard let sessionFile = probe.sessionFile else { return nil }
            return Self.codexActivity(
                turnState: codexTurnTracker.turnState(ofRolloutFile: sessionFile),
                cliStartedAt: RunningProcessInfo.startDate(of: probe.processID)
            )
        case .opencode, .pi:
            return liveSessionReporting?.report(forProcessID: probe.processID)?.activity
        case .antigravity, .kiro:
            return nil
        }
    }
}
