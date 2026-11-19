import Foundation

/// Asks a remote host, in one SSH round trip per refresh, which tmux sessions JustSessions started there still run
/// and where each tool's CLI is. Runs through the login shell so `tmux` is found on the `PATH` the host's profile
/// sets, and the CLIs wherever it puts them, as its aliases and functions too; a CLI that shell doesn't find is looked
/// for in the folders installers put it in; see `RemoteCLILocation`. What tmux prints when it can't reach the server
/// running there is kept too, so every refresh notices a tmux upgraded while sessions ran; see `RemoteHostTmuxFinding`.
enum RemoteHostStatusProbe {
    /// Comes before what `tmux list-sessions` prints, after any lines a shell profile prints.
    static let tmuxSessionsHeading = "JustSessions tmux sessions:"
    /// Separates the tmux session names above it from the CLIs the login shell finds below it. Has spaces, so it is
    /// never taken for a tmux session name.
    static let installedCLIsHeading = "JustSessions installed CLIs:"
    /// Comes after those CLIs, before the `<executable name> <path>` lines of the install folders' search.
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

    /// Nil when the host could not be reached.
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
