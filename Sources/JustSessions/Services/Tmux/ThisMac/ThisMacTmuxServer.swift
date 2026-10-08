import Foundation

/// The tmux server this Mac's tabs run their CLI in when tmux is installed. Closing a tab, quitting the app, or
/// updating it leaves the CLI running there, and resuming the session reattaches, as on an SSH host.
///
/// The server is JustSessions' own (`-L justsessions`) and reads no configuration file (`-f /dev/null`), so its
/// settings are the ones below whatever `~/.tmux.conf` says, and the user's own tmux sessions stay apart.
struct ThisMacTmuxServer: Sendable {
    static let socketName = "justsessions"

    /// Set on every attach, so a server an older JustSessions started gets them too. `-q` skips an option this
    /// tmux version lacks instead of failing the tab.
    static let globalOptions: [(name: String, value: String)] = [
        // No status line, and the wheel scrolls tmux's history: the tab looks and scrolls like the CLI alone.
        ("status", "off"),
        ("mouse", "on"),
        // No prefix key, so Ctrl-B and every other key reaches the CLI.
        ("prefix", "None"),
        // Claude Code tracks focus, and asks for this setting when it finds itself in tmux.
        ("focus-events", "on"),
        // tmux before 3.5 waits 500 ms after Esc to see whether a longer key sequence follows.
        ("escape-time", "10"),
        // The tab sends Shift-Return as CSI 13;2u (see `SelectableTerminalView`), and these pass it on unchanged,
        // so the CLI can tell it from Return.
        ("extended-keys", "always"),
        ("extended-keys-format", "csi-u"),
        // The tab's terminal gets the title the CLI sets, where a Codex CLI names its thread, and, once the CLI has
        // failed, how it ended; see `ThisMacTmuxDeadPane`.
        ("set-titles", "on"),
        ("set-titles-string", ThisMacTmuxDeadPane.titleFormat),
        // A CLI that fails keeps its pane, so its tab still shows what it printed. tmux prints no line of its own
        // under it, which would scroll the CLI's first line out of sight; the tab's bar tells the status.
        ("remain-on-exit", "failed"),
        ("remain-on-exit-format", ""),
    ]

    /// Set on every attach, like `globalOptions`. tmux 3.3, the oldest the app runs, has them all.
    static let globalHooks: [(name: String, command: String)] = [
        // A failed CLI's dead pane stays only while a tab shows it: its session ends once its last tab detaches,
        // and at once when none is attached, as the session of a CLI that exits cleanly does.
        ("pane-died", ##"if-shell -F "#{session_attached}" "set-option destroy-unattached on" "kill-session""##),
    ]

    /// tmux sets these in a session itself: `TERM` names tmux's own terminal type, the rest say the CLI runs in tmux.
    static let variablesTmuxSetsInSessions: Set<String> = ["TERM", "TERM_PROGRAM", "TERM_PROGRAM_VERSION", "TMUX", "TMUX_PANE"]

    let executablePath: String
    /// What tmux commands run with; a `TMUX_TMPDIR` in it decides where the server's socket is.
    let environment: [String: String]
    var terminfoDirectory: String? = nil

    /// The tab's command: a tmux client attached to `sessionName`, which first starts `command` in that session
    /// unless it already runs. The session starts in the client's folder, the command's own.
    func command(attachingTo sessionName: String, running command: NativeCLICommand) -> NativeCLICommand {
        let serverArguments = ["-L", Self.socketName, "-f", "/dev/null", "-u", "-T", "RGB"]
        let optionArguments = Self.globalOptions.flatMap { ["set-option", "-gq", $0.name, $0.value, ";"] }
            + Self.globalHooks.flatMap { ["set-hook", "-g", $0.name, $0.command, ";"] }
        let clientEnvironment = runtimeEnvironment(from: command.environmentVariables)
        let sessionEnvironment = clientEnvironment
            .filter { !Self.variablesTmuxSetsInSessions.contains($0.key) }
            .sorted { $0.key < $1.key }
            .flatMap { ["-e", "\($0.key)=\($0.value)"] }
        // tmux hands a command of a single argument to the user's shell, which splits a path with a space in it
        // and reads the shell's startup files. With `env` in front, tmux runs the CLI itself, as it does one with
        // arguments; `env` execs it, so the pane's process is still the CLI's.
        let program = command.arguments.isEmpty
            ? ["/usr/bin/env", command.executablePath]
            : [command.executablePath] + command.arguments
        let sessionArguments = ["-s", sessionName] + sessionEnvironment + ["--"] + program
        return NativeCLICommand(
            executablePath: executablePath,
            arguments: serverArguments + optionArguments + ["new-session", "-A"]
                + sessionArguments.map(Self.escapingCommandSeparator),
            workingDirectory: command.workingDirectory,
            // tmux refuses to start a session from inside another one.
            environment: NativeCLICommand.environmentEntries(clientEnvironment.filter { $0.key != "TMUX" && $0.key != "TMUX_PANE" })
        )
    }

    /// The JustSessions sessions the server runs; none when the server is not running.
    func sessionNames() -> Set<String> {
        TmuxSessionName.appSessionNames(inListOutput: output(of: ["list-sessions", "-F", "#{session_name}"]) ?? "")
    }

    var hasRunningSessions: Bool {
        output(of: ["list-sessions", "-F", "#{session_name}"]) != nil
    }

    /// The CLI of each session: the process of its pane. The tab's own process is only the tmux client. A session
    /// whose CLI failed, and whose pane stays while a tab shows it, runs no CLI and is left out.
    func paneProcessIDsBySessionName() -> [String: Int32] {
        Self.paneProcessIDs(inListOutput: output(of: ["list-panes", "-a", "-F", "#{session_name} #{pane_pid} #{pane_dead}"]) ?? "")
    }

    /// `paneProcessIDsBySessionName()` for the JustSessions sessions alone, as `sessionNames()` lists them.
    func appSessionPaneProcessIDs() -> [String: Int32] {
        paneProcessIDsBySessionName().filter { $0.key.hasPrefix(TmuxSessionName.prefix) }
    }

    func renameSession(from oldName: String, to newName: String) {
        _ = output(of: ["rename-session", "-t", "=\(oldName)", newName])
    }

    func killSession(named name: String) {
        _ = output(of: ["kill-session", "-t", "=\(name)"])
    }

    /// Whether this tmux is new enough for the sessions; see `ThisMacTmuxVersionCheck`. The first call for an
    /// executable runs `tmux -V`, so this is for background work.
    func hasSupportedVersion() -> Bool {
        let versionCheck = ThisMacTmuxVersionCheck.shared
        return versionCheck.answer(forExecutablePath: executablePath)
            ?? versionCheck.check(executablePath: executablePath)
            ?? false
    }

    /// Like `hasSupportedVersion()`, but never runs tmux: false until a check has run.
    var isKnownToHaveSupportedVersion: Bool {
        ThisMacTmuxVersionCheck.shared.answer(forExecutablePath: executablePath) == true
    }

    /// Parses `list-panes -F '#{session_name} #{pane_pid} #{pane_dead}'`, leaving out dead panes. The app's session
    /// names have no spaces.
    static func paneProcessIDs(inListOutput output: String) -> [String: Int32] {
        var processIDs: [String: Int32] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ")
            guard fields.count == 3, fields[2] == "0", let processID = Int32(fields[1]), processID > 0 else { continue }
            processIDs[String(fields[0])] = processID
        }
        return processIDs
    }

    /// tmux ends a command at an argument ending in `;`. A `\` before that `;` keeps it part of the argument.
    static func escapingCommandSeparator(_ argument: String) -> String {
        argument.hasSuffix(";") ? String(argument.dropLast()) + "\\;" : argument
    }

    /// The output of a tmux command on this server, or nil when it failed, e.g. because the server is not running.
    private func output(of arguments: [String]) -> String? {
        guard let result = BoundedProcessRunner.result(
            ofExecutable: executablePath,
            arguments: ["-L", Self.socketName] + arguments,
            environment: runtimeEnvironment(from: environment),
            timeout: 10
        ), result.exitStatus == 0 else { return nil }
        return result.output
    }
}
