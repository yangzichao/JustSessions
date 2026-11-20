import Foundation

/// The server is JustSessions' own (`-L justsessions`) and reads no configuration file (`-f /dev/null`), so its
/// settings are the ones below whatever `~/.tmux.conf` says, and the user's own tmux sessions stay apart.
struct ThisMacTmuxServer: Sendable {
    static let socketName = "justsessions"

    /// `-q` skips an option this tmux version lacks instead of failing the tab.
    static let globalOptions: [(name: String, value: String)] = [
        ("status", "off"),
        ("mouse", "on"),
        // No prefix key, so Ctrl-B and every other key reaches the CLI.
        ("prefix", "None"),
        // Claude Code tracks focus, and asks for this setting when it finds itself in tmux.
        ("focus-events", "on"),
        // tmux before 3.5 waits 500 ms after Esc to see whether a longer key sequence follows.
        ("escape-time", "10"),
        // tmux gives a CLI that asks for modifyOtherKeys each key as CSI u, and any other CLI the key's legacy byte
        // where it has one.
        ("extended-keys", "always"),
        ("extended-keys-format", "csi-u"),
        // The tab's terminal gets the title the CLI sets, where a Codex CLI names its thread.
        ("set-titles", "on"),
        ("set-titles-string", ThisMacTmuxDeadPane.terminalTitleFormat),
        // A CLI that fails keeps its pane, so its tab still shows what it printed. tmux prints no line of its own
        // under it, which would scroll the CLI's first line out of sight.
        ("remain-on-exit", "failed"),
        ("remain-on-exit-format", ""),
    ]

    /// tmux 3.3, the oldest the app runs, has them all.
    static let globalHooks: [(name: String, command: String)] = [
        // A failed CLI's dead pane stays only while a tab shows it: its session ends once its last tab detaches,
        // and at once when none is attached, as the session of a CLI that exits cleanly does.
        ("pane-died", ##"if-shell -F "#{session_attached}" "set-option destroy-unattached on" "kill-session""##)
    ]

    static let variablesTmuxSetsInSessions: Set<String> = ["TERM", "TERM_PROGRAM", "TERM_PROGRAM_VERSION", "TMUX", "TMUX_PANE"]

    let executablePath: String
    /// A `TMUX_TMPDIR` in it decides where the server's socket is.
    let environment: [String: String]
    var terminfoDirectory: String? = nil

    func command(attachingTo sessionName: String, running command: NativeCLICommand, historyLimit: Int? = nil) -> NativeCLICommand {
        // The tab's terminal draws RGB colors and OSC 8 hyperlinks; without `hyperlinks` tmux drops a CLI's links.
        let serverArguments = ["-L", Self.socketName, "-f", "/dev/null", "-u", "-T", "RGB,hyperlinks"]
        let optionArguments =
            Self.globalOptions.flatMap { ["set-option", "-gq", $0.name, $0.value, ";"] }
            + Self.globalHooks.flatMap { ["set-hook", "-g", $0.name, $0.command, ";"] }
        let clientEnvironment = runtimeEnvironment(from: command.environmentVariables)
        let sessionEnvironment =
            clientEnvironment
            .filter { !Self.variablesTmuxSetsInSessions.contains($0.key) }
            .sorted { $0.key < $1.key }
            .flatMap { ["-e", "\($0.key)=\($0.value)"] }
        // tmux hands a command of a single argument to the user's shell, which splits a path with a space in it
        // and reads the shell's startup files. With `env` in front, tmux runs the CLI itself, as it does one with
        // arguments; `env` execs it, so the pane's process is still the CLI's.
        let program =
            command.arguments.isEmpty
            ? ["/usr/bin/env", command.executablePath]
            : [command.executablePath] + command.arguments
        let sessionArguments = ["-s", sessionName] + sessionEnvironment + ["--"] + program
        let newSessionHistoryLimit = historyLimit.map { ThisMacTmuxNewSessionHistoryLimit(lineCount: $0, sessionName: sessionName) }
        return NativeCLICommand(
            executablePath: executablePath,
            arguments: serverArguments + optionArguments
                + (newSessionHistoryLimit?.raisingServerLimitBeforeNewSession ?? [])
                + ["new-session", "-A"] + sessionArguments.map(Self.escapingCommandSeparator)
                + (newSessionHistoryLimit?.keepingItOnTheSessionAndRestoringServerLimitAfterNewSession ?? []),
            workingDirectory: command.workingDirectory,
            // tmux refuses to start a session from inside another one.
            environment: NativeCLICommand.environmentEntries(clientEnvironment.filter { $0.key != "TMUX" && $0.key != "TMUX_PANE" })
        )
    }

    func sessionNames() -> Set<String> {
        TmuxSessionName.appSessionNames(inListOutput: output(of: ["list-sessions", "-F", "#{session_name}"]) ?? "")
    }

    var hasRunningSessions: Bool {
        output(of: ["list-sessions", "-F", "#{session_name}"]) != nil
    }

    func paneProcessIDsBySessionName() -> [String: Int32] {
        Self.paneProcessIDs(inListOutput: output(of: ["list-panes", "-a", "-F", "#{session_name} #{pane_pid} #{pane_dead}"]) ?? "")
    }

    func appSessionPaneProcessIDs() -> [String: Int32] {
        paneProcessIDsBySessionName().filter { $0.key.hasPrefix(TmuxSessionName.prefix) }
    }

    func renameSession(from oldName: String, to newName: String) {
        _ = output(of: ["rename-session", "-t", "=\(oldName)", newName])
    }

    func killSession(named name: String) {
        _ = output(of: ["kill-session", "-t", "=\(name)"])
    }

    func run(_ arguments: [String]) -> String? {
        output(of: arguments)
    }

    func hasSupportedVersion() -> Bool {
        let versionCheck = ThisMacTmuxVersionCheck.shared
        return versionCheck.answer(forExecutablePath: executablePath)
            ?? versionCheck.check(executablePath: executablePath)
            ?? false
    }

    var isKnownToHaveSupportedVersion: Bool {
        ThisMacTmuxVersionCheck.shared.answer(forExecutablePath: executablePath) == true
    }

    static func paneProcessIDs(inListOutput output: String) -> [String: Int32] {
        var processIDs: [String: Int32] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            var fields = line.split(separator: " ")
            guard fields.count >= 3 else { continue }
            let paneDead = fields.removeLast()
            let paneProcessID = fields.removeLast()
            guard paneDead == "0", let processID = Int32(paneProcessID), processID > 0 else { continue }
            processIDs[fields.joined(separator: " ")] = processID
        }
        return processIDs
    }

    /// tmux ends a command at an argument ending in `;`. A `\` before that `;` keeps it part of the argument.
    static func escapingCommandSeparator(_ argument: String) -> String {
        argument.hasSuffix(";") ? String(argument.dropLast()) + "\\;" : argument
    }

    private func output(of arguments: [String]) -> String? {
        guard
            let result = BoundedProcessRunner.result(
                ofExecutable: executablePath,
                arguments: ["-L", Self.socketName] + arguments,
                environment: runtimeEnvironment(from: environment),
                timeout: 10
            ), result.exitStatus == 0
        else { return nil }
        return result.output
    }
}
