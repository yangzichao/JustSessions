import Foundation

/// Builds the `ssh -t <host> …` command a terminal tab runs to open a session on a remote host.
/// With a tmux session name, the CLI runs inside that tmux session, so it keeps running when the connection
/// drops or the tab closes, and opening the same name again reattaches to it.
struct RemoteCLICommandBuilder {
    let inheritedEnvironment: [String: String]

    init(inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.inheritedEnvironment = inheritedEnvironment
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
                startCommand: startCommand
            )
        )
    }

    /// `ssh -t <host> <remoteCommand>`, with a terminal for the remote command.
    func sshCommand(host: String, remoteCommand: String) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: "/usr/bin/ssh",
            arguments: [
                "-t",
                // Notice a dead connection within a minute, so the tab ends and offers to reconnect.
                "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=4",
                host,
                remoteCommand,
            ],
            workingDirectory: NSHomeDirectory(),
            environment: NativeCLICommand.environmentEntries(
                TerminalColorEnvironment.embeddedTerminalEnvironment(from: inheritedEnvironment)
            )
        )
    }

    /// Runs the CLI through an interactive login shell, so the PATH set up in the host's shell profile
    /// (for example `~/.local/bin` or an nvm-managed `node`) is in effect.
    /// Without tmux on the host, the CLI runs directly.
    static func remoteCommand(
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String],
        tmuxSessionName: String? = nil,
        usesHostTmuxPrefix: Bool = false,
        startCommand: String? = nil
    ) -> String {
        let customStartCommand = CLIStartCommandLine.customCommand(startCommand)
        let cliInvocation = customStartCommand.map {
            CLIStartCommandLine.remoteInvocation(
                startCommand: $0,
                arguments: provider.argumentsAfterCustomStartCommand(arguments)
            )
        } ?? ([provider.executableName] + arguments.map(ShellQuoting.quoted)).joined(separator: " ")
        let directCommand = "cd \(ShellQuoting.quoted(projectPath)) && exec \(cliInvocation)"
        guard let tmuxSessionName else { return loginShellCommand(directCommand) }
        // `-A` attaches when the session already runs, and the options after it are set again on every attach.
        // The status line and mouse settings make it look and scroll like the CLI on its own, and with no prefix
        // key Ctrl-B reaches the CLI, unless the host uses its own; see `RemoteTmuxPrefixOptions`. These are
        // options of this session only; the host's other tmux sessions keep theirs.
        let sessionOptions = ["set-option status off", "set-option mouse on"]
            + RemoteTmuxPrefixOptions.setOptionCommands(usingHostPrefix: usesHostTmuxPrefix)
        let tmuxCommand = "exec tmux new-session -A -s \(ShellQuoting.quoted(tmuxSessionName)) "
            + ShellQuoting.quoted(loginShellCommand(directCommand))
            + sessionOptions.map { " \\; \($0)" }.joined()
        return loginShellCommand("if command -v tmux >/dev/null 2>&1; then \(tmuxCommand); else \(directCommand); fi")
    }

    static func loginShellCommand(_ innerCommand: String) -> String {
        "exec \"$SHELL\" -lic \(ShellQuoting.quoted(innerCommand))"
    }
}
