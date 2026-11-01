import Foundation

/// How JustSessions uses the checked host, for the agent that fixes what the check found, with the host's own values:
/// the agent can't see the app, and would otherwise guess.
struct HostFixAgentHostFacts: Equatable, Sendable {
    let host: String
    let shellStartup: RemoteShellStartup
    let usesHostTmuxPrefix: Bool
    /// JustSessions' tmux sessions on the host, as its last refresh listed them; nil when it couldn't list them.
    let runningTmuxSessionNames: Set<String>?
    /// What the last refresh's tmux printed when it couldn't reach the server; see `RemoteHostStatus`.
    let tmuxServerProblem: String?
    /// The session the check came from, whose tab command the facts describe; nil describes Claude Code's in a made-up
    /// folder.
    let session: HostCheckSession?

    var lines: [String] {
        let exampleProvider = session?.provider ?? .claude
        let exampleFolder = session?.projectPath ?? "/path/to/project"
        // The tab's whole command quotes the CLI's start inside the pane's command, and that inside tmux's script, so
        // it holds thousands of single quotes and backslashes, each 32 bytes once the prompt is quoted for the host:
        // Claude Code's made it over 400 KB there, too long to send. Its parts read on their own, and the agent can
        // print the rest.
        let commandWithoutTmux = RemoteCLICommandBuilder.remoteCommand(
            provider: exampleProvider,
            projectPath: exampleFolder,
            arguments: [],
            shellStartup: shellStartup
        )
        let tmuxSessionName = TmuxSessionName.forSession(provider: exampleProvider, sessionID: "<session id>")
        let sessionOptions = RemoteTmuxSessionOptions.setOptionCommands(for: exampleProvider, usingHostPrefix: usesHostTmuxPrefix)
        var lines = [
            "- Every command JustSessions runs on \(host), a tab's too, starts in the user's login shell with "
                + "\(RemoteShellStartup.environmentVariable)=1 set, as `\(shellStartup.command(running: "<command>"))`."
                + (shellStartup == .loginOnly
                    ? " It leaves out `-i` on this host, because its interactive startup files keep a CLI from starting."
                    : ""),
            "- A session's tab runs `ssh -t \(host) '<command>'`, with `-o RemoteCommand=none` and keep-alive options. "
                + "For \(exampleProvider.rawValue) in \(exampleFolder), on a host without tmux, the command is:",
            "",
            "    \(commandWithoutTmux)",
            "",
            "- With tmux, that login shell instead runs `tmux new-session -A -s \(tmuxSessionName) '<pane command>'`, "
                + "which attaches to the session or starts it, and on every attach runs "
                + sessionOptions.map { "`\($0)`" }.joined(separator: ", ") + ". On tmux 3.2 and later it also sets "
                + "`remain-on-exit failed` and a `pane-died` hook, so a CLI that fails leaves what it printed in the tab. "
                + Self.paneCommandSentence(for: exampleProvider)
                + " `tmux list-panes -a -F '#{session_name}: #{pane_start_command}'` prints each session's whole pane command.",
            "- Sessions run in the host's default tmux server, the one a plain `tmux` reaches, which the user's own tmux "
                + "sessions share. JustSessions names its sessions `\(TmuxSessionName.prefix)<cli>-<session id>`. "
                + (usesHostTmuxPrefix
                    ? "They use the prefix key from the host's ~/.tmux.conf."
                    : "They have no prefix key, so every key reaches the CLI."),
            "- " + runningTmuxSessionsLine,
            "- Each refresh copies the CLIs' session files from the host with rsync over ssh, and in one login shell lists "
                + "the tmux sessions and the CLIs installed.",
        ]
        if let session {
            lines.append("- The check came from a tab of \(session.provider?.rawValue ?? "a terminal") in \(session.projectPath).")
        }
        return lines
    }

    /// What the pane command does before the CLI starts, as in the tab's command without tmux.
    private static func paneCommandSentence(for provider: ConversationProvider) -> String {
        switch provider {
        case .codex:
            "The pane command starts the CLI in the login shell, as above."
        case .claude, .kiro, .antigravity:
            "The pane command starts JustSessions' activity relay in the background, which puts what the CLI is doing in "
                + "the session's title, and then the CLI in the login shell, as above."
        case .pi, .opencode:
            "The pane command writes JustSessions' extension, which puts what the CLI is doing in the session's title, to "
                + "`~/\(RemoteLiveSessionReporting.folder)/\(provider.executableName)`, and starts the CLI in the login shell "
                + "with it, or as above when the files can't be written."
        }
    }

    private var runningTmuxSessionsLine: String {
        if let tmuxServerProblem {
            return "The last refresh couldn't reach the tmux server; tmux printed: \(tmuxServerProblem)"
        }
        guard let runningTmuxSessionNames else { return "The last refresh couldn't list the tmux sessions." }
        guard !runningTmuxSessionNames.isEmpty else { return "The last refresh found no JustSessions tmux session running." }
        return "The last refresh found these JustSessions tmux sessions running: "
            + runningTmuxSessionNames.sorted().joined(separator: ", ") + "."
    }
}
