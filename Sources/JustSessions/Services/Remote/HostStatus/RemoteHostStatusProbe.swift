import Foundation

/// Asks a remote host, in one SSH round trip per refresh, which tmux sessions JustSessions started there still run
/// and which tools' CLIs its login shell finds. Runs through the login shell so both `tmux` and the CLIs are found
/// wherever the host's profile puts them.
enum RemoteHostStatusProbe {
    /// Separates the tmux session names above it from the installed CLIs below it. Has spaces, so it is never
    /// taken for a tmux session name.
    static let installedCLIsHeading = "JustSessions installed CLIs:"

    static var command: String {
        let cliChecks = remoteProviders.map { provider in
            let name = ShellQuoting.quoted(provider.executableName)
            return "command -v \(name) >/dev/null 2>&1 && echo \(name)"
        }
        return RemoteCLICommandBuilder.loginShellCommand(
            (["tmux list-sessions -F '#{session_name}' 2>/dev/null", "echo \(ShellQuoting.quoted(installedCLIsHeading))"] + cliChecks + ["true"])
                .joined(separator: "; ")
        )
    }

    /// Nil when the host could not be reached.
    static func status(
        ofHost host: String,
        runner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) -> RemoteHostStatus? {
        guard let result = runner.run(host, command, 30),
              result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus else { return nil }
        return status(inOutput: result.output)
    }

    /// Lines a shell profile prints come before everything else, so only lines after the heading name CLIs.
    static func status(inOutput output: String) -> RemoteHostStatus {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let headingIndex = lines.lastIndex(of: installedCLIsHeading) else {
            return RemoteHostStatus(tmuxSessionNames: TmuxSessionName.appSessionNames(inListOutput: output), installedProviders: nil)
        }
        let foundNames = Set(lines[(headingIndex + 1)...])
        return RemoteHostStatus(
            tmuxSessionNames: TmuxSessionName.appSessionNames(inListOutput: lines[..<headingIndex].joined(separator: "\n")),
            installedProviders: Set(remoteProviders.filter { foundNames.contains($0.executableName) })
        )
    }

    private static var remoteProviders: [ConversationProvider] {
        ConversationProvider.allCases.filter(\.supportsRemoteHosts)
    }
}
