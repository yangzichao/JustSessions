import Foundation

enum RemoteHostStatusProbe {
    static let tmuxSessionsHeading = "JustSessions tmux sessions:"
    static let installedCLIsHeading = "JustSessions installed CLIs:"
    static let installFoldersHeading = "JustSessions CLIs in install folders:"
    /// `tmux list-sessions`, whose output goes to a file first: an older tmux server, as 2.6, keeps the output of a
    /// newer client open, which would hold the connection until the refresh gives up; see `RemoteHostCheckScript`.
    /// Where `mktemp` fails, tmux prints to the connection. `sh` runs it, as it runs a tab's tmux.
    static let tmuxSessionsScript =
        "tmux_out=$(mktemp 2>/dev/null)"
        + " || exec tmux list-sessions -F '#{session_name}' 2>&1;"
        + " tmux list-sessions -F '#{session_name}' </dev/null >\"$tmux_out\" 2>&1;"
        + " cat \"$tmux_out\"; rm -f \"$tmux_out\""

    static func command(on host: String) -> String {
        command(startup: RemoteHostShellStartups.shared.startup(on: host))
    }

    /// `type` finds aliases and functions as well as programs, in fish too, whose `command -v` finds only programs.
    static func command(startup: RemoteShellStartup) -> String {
        let executableNames = ConversationProvider.allCases.map(\.executableName)
        let cliChecks = executableNames.map { name in
            let name = ShellQuoting.quoted(name)
            return "type \(name) >/dev/null 2>&1 && echo \(name)"
        }
        let installFoldersSearch = "sh -c " + ShellQuoting.quoted(RemoteCLIInstallFolders.searchScript(executableNames: executableNames))
        return startup.command(
            running: ([
                "echo \(ShellQuoting.quoted(tmuxSessionsHeading))",
                "sh -c " + ShellQuoting.quoted(tmuxSessionsScript),
                "echo \(ShellQuoting.quoted(installedCLIsHeading))",
            ]
                + cliChecks
                + ["echo \(ShellQuoting.quoted(installFoldersHeading))", installFoldersSearch, "true"])
                .joined(separator: "; ")
        )
    }

    static func status(
        ofHost host: String,
        runner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) -> RemoteHostStatus? {
        status(ofHost: host, startup: RemoteHostShellStartups.shared.startup(on: host), runner: runner)
    }

    static func status(
        ofHost host: String,
        startup: RemoteShellStartup,
        runner: RemoteHostCommandRunner = RemoteHostCommandRunner()
    ) -> RemoteHostStatus? {
        guard let result = runner.run(host, command(startup: startup), 30),
            result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus
        else { return nil }
        return status(inOutput: result.output)
    }

    /// Lines a shell profile prints come before everything else, so only lines after the headings are tmux's or
    /// name CLIs.
    static func status(inOutput output: String) -> RemoteHostStatus {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let headingIndex = lines.lastIndex(of: installedCLIsHeading) else {
            return RemoteHostStatus(tmuxSessionNames: TmuxSessionName.appSessionNames(inListOutput: output), cliLocations: nil)
        }
        let tmuxLines =
            lines[..<headingIndex].lastIndex(of: tmuxSessionsHeading)
            .map { lines[($0 + 1)..<headingIndex] } ?? lines[..<headingIndex]
        let tmuxOutput = tmuxLines.joined(separator: "\n")
        let foldersHeadingIndex = lines[headingIndex...].firstIndex(of: installFoldersHeading) ?? lines.endIndex
        let namesFoundByLoginShell = Set(lines[(headingIndex + 1)..<foldersHeadingIndex])
        let installFolderPaths = lines.dropFirst(foldersHeadingIndex + 1).compactMap { line -> (name: String, path: String)? in
            guard let space = line.firstIndex(of: " ") else { return nil }
            return (String(line[..<space]), String(line[line.index(after: space)...]))
        }
        var cliLocations: [ConversationProvider: RemoteCLILocation] = [:]
        for provider in ConversationProvider.allCases {
            if namesFoundByLoginShell.contains(provider.executableName) {
                cliLocations[provider] = .loginShell
            } else if let path = RemoteCLIInstallFolders.preferredPath(
                among: installFolderPaths.filter { $0.name == provider.executableName }.map(\.path)
            ) {
                cliLocations[provider] = .installed(path: path)
            }
        }
        return RemoteHostStatus(
            tmuxSessionNames: TmuxSessionName.appSessionNames(inListOutput: tmuxOutput),
            cliLocations: cliLocations,
            tmuxServerProblem: RemoteHostTmuxFinding.unreachableServerMessage(in: tmuxOutput)
        )
    }
}
