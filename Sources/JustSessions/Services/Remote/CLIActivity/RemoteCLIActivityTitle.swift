import Foundation

/// The title a Claude Code, Pi, OpenCode, Kiro CLI, or Antigravity tab's tmux session on an SSH host gives the tab: what
/// the CLI does, after `titlePrefix`, as the host keeps it in `optionName`. Claude Code's relay sets it from the CLI's
/// record in the host's live registry (`RemoteClaudeActivityRelay`), Kiro CLI's relay from its turn markers there
/// (`RemoteKiroActivityRelay`), Antigravity's from its conversation database (`RemoteAntigravityActivityRelay`), and
/// Pi's and OpenCode's extensions from what they report on this Mac (`RemoteLiveSessionReporting`). Until it is set, as before the CLI says anything, the title is the CLI's own, except
/// that tmux 2.6 shows the prefix alone. The app shows neither; it only reads what the CLI does from it.
enum RemoteCLIActivityTitle {
    static let providers: Set<ConversationProvider> = [.claude, .pi, .opencode, .kiro, .antigravity]
    static let optionName = "@justsessions-activity"
    static let titlePrefix = "justsessions-activity:"
    static let titleFormat = "#{?\(optionName),\(titlePrefix)#{\(optionName)},#T}"

    static func activity(inTerminalTitle title: String, of provider: ConversationProvider) -> CLIActivity? {
        if provider == .claude, let record = RemoteClaudeSessionTitle.record(inTerminalTitle: title) {
            return record.activity
        }
        guard title.hasPrefix(titlePrefix) else { return nil }
        let value = title.dropFirst(titlePrefix.count)
        let state = String(value.prefix { $0 != ":" })
        let waitingFor = value.dropFirst(state.count).dropFirst()
        let reason = waitingFor.isEmpty ? nil : String(waitingFor)
        switch provider {
        case .claude: return ClaudeLiveSessionRecord.activity(status: state, waitingFor: reason)
        case .pi, .opencode: return LiveSessionReport.activity(named: state, waitingFor: reason)
        case .kiro: return KiroTurnMarkers.activity(named: state)
        case .antigravity: return RemoteAntigravityActivityRelay.activity(named: state)
        case .codex: return nil
        }
    }
}
