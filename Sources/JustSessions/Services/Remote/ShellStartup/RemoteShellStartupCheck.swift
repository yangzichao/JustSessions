import Foundation

/// Finds out whether an SSH host's interactive shell startup lets the app's commands run, as a tab runs them: in a
/// terminal, through `RemoteShellStartup.interactive`. Some startup files start another program for every
/// interactive shell, such as tmux or another shell; a tab then shows that program's prompt instead of the CLI. Such a
/// host gets `RemoteShellStartup.loginOnly` when a login shell without the interactive startup runs the app's
/// command; otherwise its startup files need a change, which the user guide explains.
///
/// Each step runs a marker command in a terminal and looks for what it prints. bash and zsh also trace their startup,
/// so the last command they ran says where it stopped. A terminal is needed, since startup files often start that
/// program only in one; letting it start can leave it running on the host, so the check runs rarely.
struct RemoteShellStartupCheck: Sendable {
    /// Runs a command on the host in a terminal. The exit status is nil when the command ran past the timeout.
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32?, output: String)?
    let timeout: TimeInterval

    /// Startup that takes longer than `timeout` counts as having started another program, so it is generous.
    init(
        run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32?, output: String)?)? = nil,
        timeout: TimeInterval = 20
    ) {
        self.run = run ?? { host, command, timeout in
            BoundedProcessRunner.outcome(
                ofExecutable: "/usr/bin/ssh",
                arguments: ["-tt"] + RemoteHostCommandRunner.sshArguments(host: host, command: command),
                // A tab's terminal settings, which startup files may look at, such as TERM.
                environment: TerminalColorEnvironment.embeddedTerminalEnvironment(from: ProcessInfo.processInfo.environment),
                includesStandardError: true,
                timeout: timeout
            )
        }
        self.timeout = timeout
    }

    /// Nil when it could not tell, as when the host could not be reached; a later refresh checks again.
    func check(host: String) -> RemoteShellStartupCheckResult? {
        guard let interactive = conclusiveRun(host, Self.tracedInteractiveCommand) else { return nil }
        if Self.printedMarker(interactive.output) {
            return RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil)
        }
        guard let loginOnly = conclusiveRun(host, Self.loginOnlyCommand) else { return nil }
        return RemoteShellStartupCheckResult(
            outcome: Self.printedMarker(loginOnly.output) ? .usesLoginShellOnly : .blocked,
            stoppedAt: Self.lastTracedCommand(in: interactive.output)
        )
    }

    /// Nil when `ssh` could not connect, or when nothing came back before the timeout, as when the connection stalled.
    private func conclusiveRun(_ host: String, _ command: String) -> (exitStatus: Int32?, output: String)? {
        guard let result = run(host, command, timeout),
              result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus,
              result.exitStatus != nil || !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return result
    }

    // MARK: - Commands

    static let marker = "__JUSTSESSIONS_SHELL_STARTUP_OK__"
    /// Short, since bash 3.2 cuts its trace prefix off at about 100 characters, location included.
    static let traceMarker = "JUSTSESSIONS "

    /// Prints the marker from two halves, so a shell that echoes or traces the command doesn't print it whole.
    static let markerCommand = "printf '%s%s\\n' __JUSTSESSIONS_SHELL_ STARTUP_OK__"

    /// `RemoteShellStartup.interactive`, traced when the host's shell is bash or zsh. `/bin/sh` reads it, whatever the
    /// host's own shell.
    static var tracedInteractiveCommand: String {
        let script = """
            case "${SHELL##*/}" in
            bash) PS4='+\(traceMarker)${BASH_SOURCE:-$0}:${LINENO}: '; export PS4; flags=-lixc ;;
            zsh) PS4='+\(traceMarker)%x:%I: '; export PS4; flags=-lixc ;;
            *) flags=-lic ;;
            esac
            exec /usr/bin/env \(RemoteShellStartup.environmentVariable)=1 "$SHELL" "$flags" \(ShellQuoting.quoted(markerCommand))
            """
        return "exec /bin/sh -c \(ShellQuoting.quoted(script))"
    }

    static var loginOnlyCommand: String {
        RemoteShellStartup.loginOnly.command(running: markerCommand)
    }

    // MARK: - Output

    /// Anywhere in a line, after whatever the terminal printed first; the commands hold it only in halves.
    static func printedMarker(_ output: String) -> Bool {
        lines(of: output).contains { $0.contains(marker) }
    }

    /// `file:line: command` from the last line the startup's trace printed, shortened for a tooltip.
    static func lastTracedCommand(in output: String) -> String? {
        guard let line = lines(of: output).last(where: { $0.drop(while: { $0 == "+" }).hasPrefix(traceMarker) })
        else { return nil }
        let command = line.drop(while: { $0 == "+" }).dropFirst(traceMarker.count)
            .trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return nil }
        return command.count > 160 ? String(command.prefix(159)) + "…" : command
    }

    /// The output's lines without terminal escape sequences, carriage returns, or other control characters.
    private static func lines(of output: String) -> [String] {
        let withoutEscapes = output.replacingOccurrences(
            of: "\u{1B}(\\[[0-9;?]*[ -/]*[@-~]|\\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\\\)|[@-_])",
            with: "",
            options: .regularExpression
        )
        return withoutEscapes.split(whereSeparator: \.isNewline).map { line in
            String(line.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == "\t" })
                .trimmingCharacters(in: .whitespaces)
        }
    }
}
