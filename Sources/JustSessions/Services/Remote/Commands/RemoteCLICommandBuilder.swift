import Foundation

struct RemoteCLICommandBuilder {
    let inheritedEnvironment: [String: String]
    let loginConnections: SSHLoginConnections
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

    func sshCommand(host: String, remoteCommand: String) -> NativeCLICommand {
        NativeCLICommand(
            sshTab: SSHTabArguments(
                loginOptions: loginConnections.connectionOptions(for: host),
                optionsAndRemoteCommand: SSHConnectTimeout.options
                    + ["-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=4"]
                    + keystrokeTimingOptions
                    + [
                        // With a `RemoteCommand` in `~/.ssh/config`, `ssh` would refuse to run the tab's command.
                        "-o", "RemoteCommand=none",
                        host,
                        remoteCommand,
                    ]
            ),
            environment: NativeCLICommand.environmentEntries(
                TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
            )
        )
    }

    func withCurrentLogin(_ command: NativeCLICommand, host: String) -> NativeCLICommand {
        guard let sshTabArguments = command.sshTabArguments else { return command }
        return NativeCLICommand(
            sshTab: sshTabArguments.throughLogin(options: loginConnections.connectionOptions(for: host)),
            environment: command.environment
        )
    }

    /// What the tab's login shells on the host set for the CLI and for tmux. `ssh` gives the host the tab's `TERM` but
    /// not its `COLORTERM`. Without it a CLI in tmux before 3.3, whose terminal is `screen`, keeps to the 16 ANSI
    /// colors, and Claude Code draws its selection in ANSI black, the background of themes such as Atom One Dark.
    /// tmux 3.6 and later also read it as the tab showing RGB colors.
    static let terminalEnvironment = ["COLORTERM=truecolor"]

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
        func cliStartCommand(after quotedLeadingArguments: [String]) -> String {
            CLIStartCommandLine.customCommand(startCommand).map {
                let invocation = CLIStartCommandLine.remoteInvocation(
                    startCommand: $0,
                    quotedArguments: quotedLeadingArguments
                        + provider.argumentsAfterCustomStartCommand(arguments).map(ShellQuoting.quoted)
                )
                return "cd \(ShellQuoting.quoted(projectPath)) && exec \(invocation)"
            }
                ?? RemoteCLIInvocation.startCommand(
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
        let paneCommand =
            switch provider {
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

    static func loginShellCommand(_ innerCommand: String, on host: String) -> String {
        RemoteHostShellStartups.shared.startup(on: host).command(running: innerCommand)
    }
}
