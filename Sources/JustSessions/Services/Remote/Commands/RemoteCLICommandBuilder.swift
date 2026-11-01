import Foundation

/// Builds the `ssh -t <host> …` command a terminal tab runs to open a session on a remote host.
/// With a tmux session name, the CLI runs inside that tmux session, so it keeps running when the connection
/// drops or the tab closes, and opening the same name again reattaches to it.
struct RemoteCLICommandBuilder {
    let inheritedEnvironment: [String: String]
    let loginConnections: SSHLoginConnections
    /// See `SSHKeystrokeTiming`.
    let keystrokeTimingOptions: [String]

    init(
        inheritedEnvironment: [String: String] = SSHProcessEnvironment.standard,
        loginConnections: SSHLoginConnections = .shared,
        keystrokeTimingOptions: [String] = SSHKeystrokeTiming.options
    ) {
        self.inheritedEnvironment = inheritedEnvironment
        self.loginConnections = loginConnections
        self.keystrokeTimingOptions = keystrokeTimingOptions
    }

    /// `startCommand` is one set in the New session sheet; nil starts the tool's own executable. It stands in for
    /// `defaultStartCommand`, so the app's arguments that follow leave out what it holds. `usesHostTmuxPrefix` is the
    /// host's choice in `RemoteHostsUsingTmuxPrefix`, so every tab's command passes it.
    func command(
        host: String,
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String],
        tmuxSessionName: String? = nil,
        usesHostTmuxPrefix: Bool,
        startCommand: String? = nil
    ) -> NativeCLICommand {
        sshCommand(
            host: host,
            remoteCommand: Self.remoteCommand(
                provider: provider,
                projectPath: projectPath,
                arguments: arguments,
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: usesHostTmuxPrefix,
                startCommand: startCommand,
                shellStartup: RemoteHostShellStartups.shared.startup(on: host),
                cliLocation: RemoteHostCLILocations.shared.location(of: provider, on: host)
            )
        )
    }

    /// `ssh -t <host> <remoteCommand>`, with a terminal for the remote command. On a host logged in to with
    /// Connect…, the tab goes through that login, so it asks nothing; without one, `ssh` asks in the tab's terminal.
    func sshCommand(host: String, remoteCommand: String) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: "/usr/bin/ssh",
            arguments: ["-t"]
                + loginConnections.connectionOptions(for: host)
                + [
                    // A host that doesn't answer ends the tab within 10 seconds, as the background commands do,
                    // instead of after the system's own connection timeout.
                    "-o", "ConnectTimeout=10",
                    // Notice a dead connection within a minute, so the tab ends and offers to reconnect.
                    "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=4",
                ]
                + keystrokeTimingOptions
                + [
                    // With a `RemoteCommand` in `~/.ssh/config`, `ssh` would refuse to run the tab's command.
                    "-o", "RemoteCommand=none",
                    host,
                    remoteCommand,
                ],
            workingDirectory: NSHomeDirectory(),
            environment: NativeCLICommand.environmentEntries(
                TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
            )
        )
    }

    /// A tab's command to connect again, through the host's login open now: the login it went through may have
    /// closed since, and Connect… may have opened another, or the first, since the tab opened.
    func withCurrentLogin(_ command: NativeCLICommand, host: String) -> NativeCLICommand {
        var arguments = command.arguments
        if Self.goesThroughLogin(command) { arguments.removeSubrange(1...4) }
        arguments.insert(contentsOf: loginConnections.connectionOptions(for: host), at: 1)
        return NativeCLICommand(
            executablePath: command.executablePath,
            arguments: arguments,
            workingDirectory: command.workingDirectory,
            environment: command.environment
        )
    }

    /// Whether a tab's command connects through a login made with Connect…, whose options `sshCommand` puts right
    /// after `-t`.
    static func goesThroughLogin(_ command: NativeCLICommand) -> Bool {
        let arguments = command.arguments
        return arguments.count > 5 && Array(arguments[1...3]) == ["-o", "ControlMaster=no", "-o"]
            && arguments[4].hasPrefix("ControlPath=")
    }

    /// What the tab's login shells on the host set for the CLI and for tmux. `ssh` gives the host the tab's `TERM` but
    /// not its `COLORTERM`. Without it a CLI in tmux before 3.3, whose terminal is `screen`, keeps to the 16 ANSI
    /// colors, and Claude Code draws its selection in ANSI black, the background of themes such as Atom One Dark.
    /// tmux 3.6 and later also read it as the tab showing RGB colors.
    static let terminalEnvironment = ["COLORTERM=truecolor"]

    /// Runs the CLI through the host's login shell, so the PATH set up in the host's shell profile
    /// (for example `~/.local/bin` or an nvm-managed `node`) is in effect, and so are its aliases and functions; see
    /// `RemoteShellStartup` and `RemoteCLIInvocation`. Without tmux on the host, the CLI runs directly.
    static func remoteCommand(
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String],
        tmuxSessionName: String? = nil,
        usesHostTmuxPrefix: Bool = false,
        startCommand: String? = nil,
        shellStartup: RemoteShellStartup = .interactive,
        cliLocation: RemoteCLILocation = .loginShell
    ) -> String {
        // Codex says which thread it is in, and what it is doing, only in its terminal title, and only when asked, as
        // on this Mac; see `CodexThreadTitle` and `CodexTitleActivity`.
        let titleArguments = provider == .codex ? CodexThreadTitle.launchArguments.map(ShellQuoting.quoted) : []
        // Starts the CLI with these words, already quoted, in front of the app's arguments.
        func cliStartCommand(after quotedLeadingArguments: [String]) -> String {
            CLIStartCommandLine.customCommand(startCommand).map {
                let invocation = CLIStartCommandLine.remoteInvocation(
                    startCommand: $0,
                    quotedArguments: quotedLeadingArguments
                        + provider.argumentsAfterCustomStartCommand(arguments).map(ShellQuoting.quoted)
                )
                return "cd \(ShellQuoting.quoted(projectPath)) && exec \(invocation)"
            } ?? RemoteCLIInvocation.startCommand(
                executableName: provider.executableName,
                location: cliLocation,
                projectPath: projectPath,
                quotedArguments: quotedLeadingArguments + arguments.map(ShellQuoting.quoted)
            )
        }
        let directCommand = cliStartCommand(after: titleArguments)
        func inLoginShell(_ command: String, environment: [String] = []) -> String {
            shellStartup.command(running: command, environment: terminalEnvironment + environment)
        }
        guard let tmuxSessionName else { return inLoginShell(directCommand) }
        // `-A` attaches when the session already runs, and the options after it are set again on every attach; see
        // `RemoteTmuxSessionOptions`.
        let paneCommand = switch provider {
        case .claude:
            inLoginShell("\(RemoteClaudeActivityRelay.launchCommand); \(directCommand)")
        case .kiro:
            inLoginShell("\(RemoteKiroActivityRelay.launchCommand); \(directCommand)")
        case .antigravity:
            inLoginShell("\(RemoteAntigravityActivityRelay.launchCommand); \(directCommand)")
        case .pi, .opencode:
            RemoteLiveSessionReporting.command(
                for: provider,
                reporting: inLoginShell(
                    cliStartCommand(after: titleArguments + RemoteLiveSessionReporting.quotedArguments(for: provider)),
                    environment: RemoteLiveSessionReporting.environment(for: provider)
                ),
                otherwise: inLoginShell(directCommand)
            )
        case .codex:
            inLoginShell(directCommand)
        }
        let tmuxCommand = RemoteTmuxAttachScript.command(
            sessionName: tmuxSessionName,
            paneCommand: paneCommand,
            sessionOptions: RemoteTmuxSessionOptions.setOptionCommands(for: provider, usingHostPrefix: usesHostTmuxPrefix)
        )
        // The login shell may be fish, which has no `if …; then …; fi`; `&&` and `;` read the same in both. When tmux
        // is found, `exec` replaces the shell, so the CLI runs directly only without it.
        return inLoginShell("command -v tmux >/dev/null 2>&1 && \(tmuxCommand); \(directCommand)")
    }

    /// Runs `innerCommand` in the host's login shell, started as the host needs; see `RemoteShellStartup`.
    static func loginShellCommand(_ innerCommand: String, on host: String) -> String {
        RemoteHostShellStartups.shared.startup(on: host).command(running: innerCommand)
    }
}
