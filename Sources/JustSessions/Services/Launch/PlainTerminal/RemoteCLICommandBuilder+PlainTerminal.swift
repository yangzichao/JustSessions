import Foundation

extension RemoteCLICommandBuilder {
    /// Your login shell on the host, in the folder. With a tmux session name, the shell runs in that tmux session when
    /// the host has tmux, so it keeps running when the connection drops or the app quits, and the same name attaches to
    /// it again; on a host without tmux it runs directly and ends with its tab.
    func plainTerminalCommand(
        host: String,
        projectPath: String,
        tmuxSessionName: String? = nil,
        usesHostTmuxPrefix: Bool = false
    ) -> NativeCLICommand {
        sshCommand(
            host: host,
            remoteCommand: Self.remotePlainTerminalCommand(
                projectPath: projectPath,
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: usesHostTmuxPrefix,
                shellStartup: RemoteHostShellStartups.shared.startup(on: host)
            )
        )
    }

    /// The shell starts as a login shell, as a new SSH login's does, and without `JUSTSESSIONS`, which tells startup
    /// files that the app runs a command rather than you a shell (SSH-24). The tmux client is started in the login shell
    /// that sets it, as a CLI tab's is, so it finds `tmux` wherever the host's startup files put it; tmux passes that
    /// shell's environment on to the panes of a server it starts, so the pane's shell drops the variable again.
    static func remotePlainTerminalCommand(
        projectPath: String,
        tmuxSessionName: String? = nil,
        usesHostTmuxPrefix: Bool = false,
        shellStartup: RemoteShellStartup = .interactive
    ) -> String {
        let directCommand = "cd \(ShellQuoting.quoted(projectPath)) && exec \"$SHELL\" -l"
        guard let tmuxSessionName else { return directCommand }
        let paneCommand = "cd \(ShellQuoting.quoted(projectPath)) && exec /usr/bin/env -u \(RemoteShellStartup.environmentVariable) \"$SHELL\" -l"
        let tmuxCommand = RemoteTmuxAttachScript.command(
            sessionName: tmuxSessionName,
            paneCommand: paneCommand,
            sessionOptions: RemoteTmuxSessionOptions.setOptionCommandsForPlainTerminal(usingHostPrefix: usesHostTmuxPrefix)
        )
        // As a CLI tab's: `exec` replaces the login shell when tmux is found, so the shell starts directly only without it.
        return shellStartup.command(
            running: "command -v tmux >/dev/null 2>&1 && \(tmuxCommand); \(paneCommand)",
            environment: terminalEnvironment
        )
    }
}
