import Foundation

/// The tmux session a plain terminal's shell runs in, and how to run tmux commands on its server, on this Mac or its
/// SSH host, for finding text in its history; see `TmuxHistoryFinder`.
struct TmuxHistory: Sendable {
    let sessionName: String
    /// Runs tmux with these arguments and returns what it printed, or nil when it failed. It waits for tmux, over SSH
    /// for the host's, so it runs off the main actor.
    let runTmux: @Sendable (_ arguments: [String]) -> String?
}

extension TmuxHistory {
    static func onThisMac(sessionName: String, server: ThisMacTmuxServer) -> TmuxHistory {
        TmuxHistory(sessionName: sessionName) { server.run($0) }
    }

    /// Through the host's login shell, as the other tmux commands for its sessions go (`RemoteTmuxCommands`), so
    /// `tmux` is found wherever the host's startup files put it.
    static func onSSHHost(
        _ host: String,
        sessionName: String,
        remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) -> TmuxHistory {
        TmuxHistory(sessionName: sessionName) { arguments in
            let tmuxCommand = (["tmux"] + arguments.map(ShellQuoting.quoted)).joined(separator: " ")
            let command = RemoteCLICommandBuilder.loginShellCommand(tmuxCommand, on: host)
            guard let result = remoteRunner.run(host, command, 15), result.exitStatus == 0 else { return nil }
            return result.output
        }
    }
}
