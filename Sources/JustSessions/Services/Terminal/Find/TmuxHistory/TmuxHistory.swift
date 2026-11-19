import Foundation

struct TmuxHistory: Sendable {
    let sessionName: String
    let runTmux: @Sendable (_ arguments: [String]) -> String?
}

extension TmuxHistory {
    static func onThisMac(sessionName: String, server: ThisMacTmuxServer) -> TmuxHistory {
        TmuxHistory(sessionName: sessionName) { server.run($0) }
    }

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
