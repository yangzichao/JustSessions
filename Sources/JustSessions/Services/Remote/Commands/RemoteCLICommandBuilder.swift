import Foundation

/// Builds the `ssh -t <host> …` command a terminal tab runs to open a session on a remote host.
/// With a tmux session name, the CLI runs inside that tmux session, so it keeps running when the connection
/// drops or the tab closes, and opening the same name again reattaches to it.
struct RemoteCLICommandBuilder {
    let inheritedEnvironment: [String: String]

    init(inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.inheritedEnvironment = inheritedEnvironment
    }

    func command(
        host: String,
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String],
        tmuxSessionName: String? = nil
    ) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: "/usr/bin/ssh",
            arguments: [
                "-t",
                // Notice a dead connection within a minute, so the tab ends and offers to reconnect.
                "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=4",
                host,
                Self.remoteCommand(
                    provider: provider,
                    projectPath: projectPath,
                    arguments: arguments,
                    tmuxSessionName: tmuxSessionName
                ),
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
        tmuxSessionName: String? = nil
    ) -> String {
        let cliInvocation = ([provider.executableName] + arguments.map(ShellQuoting.quoted)).joined(separator: " ")
        let directCommand = "cd \(ShellQuoting.quoted(projectPath)) && exec \(cliInvocation)"
        guard let tmuxSessionName else { return loginShellCommand(directCommand) }
        // `-A` attaches when the session already runs. The status line and mouse settings make it look and
        // scroll like the CLI on its own, and with no prefix key Ctrl-B reaches the CLI. These are options of
        // this session only; the host's other tmux sessions keep theirs.
        let tmuxCommand = "exec tmux new-session -A -s \(ShellQuoting.quoted(tmuxSessionName)) "
            + ShellQuoting.quoted(loginShellCommand(directCommand))
            + " \\; set-option status off \\; set-option mouse on \\; set-option prefix None"
        return loginShellCommand("if command -v tmux >/dev/null 2>&1; then \(tmuxCommand); else \(directCommand); fi")
    }

    static func loginShellCommand(_ innerCommand: String) -> String {
        "exec \"$SHELL\" -lic \(ShellQuoting.quoted(innerCommand))"
    }
}
