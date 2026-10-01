import Foundation

extension RemoteCLICommandBuilder {
    /// Your login shell on the host, in the folder. Unlike a CLI's, it runs outside tmux, so it ends with its tab.
    func plainTerminalCommand(host: String, projectPath: String) -> NativeCLICommand {
        sshCommand(host: host, remoteCommand: Self.remotePlainTerminalCommand(projectPath: projectPath))
    }

    static func remotePlainTerminalCommand(projectPath: String) -> String {
        "cd \(ShellQuoting.quoted(projectPath)) && exec \"$SHELL\" -l"
    }
}
