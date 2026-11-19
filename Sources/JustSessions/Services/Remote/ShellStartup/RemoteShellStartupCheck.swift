import Foundation

struct RemoteShellStartupCheck: Sendable {
    let run: @Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32?, output: String)?
    let timeout: TimeInterval

    init(
        reachability: SSHHostReachability = .shared,
        run: (@Sendable (_ host: String, _ command: String, _ timeout: TimeInterval) -> (exitStatus: Int32?, output: String)?)? = nil,
        timeout: TimeInterval = 20
    ) {
        self.run =
            run ?? { host, command, timeout in
                if let failureOutput = reachability.recentFailureOutput(on: host) {
                    return (RemoteHostCommandRunner.connectionFailureExitStatus, failureOutput)
                }
                let result = BoundedProcessRunner.outcome(
                    ofExecutable: "/usr/bin/ssh",
                    arguments: Self.sshArguments(
                        host: host,
                        command: command,
                        connectionSharingOptions: SSHLoginConnections.shared.connectionOptions(for: host)
                    ),
                    environment: TerminalColorEnvironment.embeddedTerminalEnvironment(from: SSHProcessEnvironment.standard),
                    includesStandardError: true,
                    timeout: timeout,
                    cancelsWithTask: true
                )
                if let result, let exitStatus = result.exitStatus {
                    reachability.noteResult(exitStatus: exitStatus, output: result.output, on: host)
                }
                return result
            }
        self.timeout = timeout
    }

    static func sshArguments(host: String, command: String, connectionSharingOptions: [String]) -> [String] {
        ["-tt"] + RemoteHostCommandRunner.nonInteractiveSSHOptions + connectionSharingOptions + [host, command]
    }

    func check(host: String) -> RemoteShellStartupCheckResult? {
        guard !Task.isCancelled else { return nil }
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

    private func conclusiveRun(_ host: String, _ command: String) -> (exitStatus: Int32?, output: String)? {
        guard !Task.isCancelled else { return nil }
        guard let result = run(host, command, timeout),
            result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus,
            result.exitStatus != nil || !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return result
    }

    static let marker = "__JUSTSESSIONS_SHELL_STARTUP_OK__"
    /// Short, since bash 3.2 cuts its trace prefix off at about 100 characters, location included.
    static let traceMarker = "JUSTSESSIONS "

    /// Prints the marker from two halves, so a shell that echoes or traces the command doesn't print it whole.
    static let markerCommand = "printf '%s%s\\n' __JUSTSESSIONS_SHELL_ STARTUP_OK__"

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

    static func printedMarker(_ output: String) -> Bool {
        lines(of: output).contains { $0.contains(marker) }
    }

    static func lastTracedCommand(in output: String) -> String? {
        guard let line = lines(of: output).last(where: { $0.drop(while: { $0 == "+" }).hasPrefix(traceMarker) })
        else { return nil }
        let command = line.drop(while: { $0 == "+" }).dropFirst(traceMarker.count)
            .trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return nil }
        return command.count > 160 ? String(command.prefix(159)) + "…" : command
    }

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
