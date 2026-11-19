import Foundation

/// What the app's tmux sessions on an SSH host show of their CLIs, read on the host without a tab: the window option
/// where Claude Code's relay and Pi's and OpenCode's extensions keep what the CLI does (`RemoteCLIActivityTitle`), and
/// the pane's title, where Codex says it (`CodexTitleActivity`). A tab gets the same through its title, but a session
/// whose tab closed with its CLI kept running has no tab to pass it on, so the app asks the host instead; see
/// `RemoteDetachedActivityReader`.
struct RemoteTmuxPanes: Equatable, Sendable {
    struct Pane: Equatable, Sendable {
        /// `<state>:<what it waits for>`, or empty while the CLI has said nothing.
        let activityOption: String
        let title: String
    }

    let panesBySessionName: [String: Pane]

    /// Printed once the listing is done, so a cut-off answer isn't taken for sessions that ended.
    static let endMarker = "justsessions-panes-listed"
    /// Parts the fields. tmux prints a tab, or any other control character, as `_`, so it is printable; a session name
    /// has none, and the title, which may have anything, comes last.
    static let separator = " ~js~ "
    static let format = "#{session_name}\(separator)#{\(RemoteCLIActivityTitle.optionName)}\(separator)#{pane_title}"

    /// Lists the panes of the host's tmux server. A host without tmux, or without a running server, lists none. `sh`
    /// runs it, as the login shell may be fish; the login shell finds `tmux` as the tab's does.
    static func command(on host: String) -> String {
        let script =
            "command -v tmux >/dev/null 2>&1 || exit 0; tmux list-panes -a -F \(ShellQuoting.quoted(format)) 2>&1; echo \(endMarker)"
        return RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    /// Nil unless the listing finished, and when tmux can't reach the server that runs, as after an upgrade: its
    /// sessions run on, out of reach. Lines a shell profile prints, and tmux's "no server running", name no pane.
    static func panes(inOutput output: String) -> RemoteTmuxPanes? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.contains(endMarker),
            RemoteHostTmuxFinding.unreachableServerMessage(in: output) == nil
        else { return nil }
        var panes: [String: Pane] = [:]
        for line in lines {
            let fields = line.components(separatedBy: separator)
            guard fields.count >= 3, fields[0].hasPrefix(TmuxSessionName.prefix) else { continue }
            // A session's first pane; the app's sessions have one.
            if panes[fields[0]] == nil {
                panes[fields[0]] = Pane(activityOption: fields[1], title: fields[2...].joined(separator: separator))
            }
        }
        return RemoteTmuxPanes(panesBySessionName: panes)
    }

    /// What the CLI in the session does, as a tab would read it from its title; nil while it says nothing, and for a
    /// CLI that tells nothing.
    func activity(of provider: ConversationProvider, inSession name: String) -> CLIActivity? {
        guard let pane = panesBySessionName[name] else { return nil }
        if RemoteCLIActivityTitle.providers.contains(provider) {
            guard !pane.activityOption.isEmpty else { return nil }
            return RemoteCLIActivityTitle.activity(inTerminalTitle: RemoteCLIActivityTitle.titlePrefix + pane.activityOption, of: provider)
        }
        return provider == .codex ? CodexTitleActivity.activity(inTerminalTitle: pane.title) : nil
    }
}
