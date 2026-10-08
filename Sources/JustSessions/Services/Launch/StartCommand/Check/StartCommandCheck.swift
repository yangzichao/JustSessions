import Foundation

/// Checks a start command before it is kept, so one that cannot start does not break every later launch of the tool
/// on the host, resumes included. The command is read without running it, see `StartCommandShape`, and its program is
/// looked up where the CLI would run: on this Mac on the PATH the app gives CLIs, on an SSH host in its login shell.
/// Flags are not checked; only the program knows its own.
struct StartCommandCheck: Sendable {
    static let thisMacTimeout: TimeInterval = 10
    static let remoteTimeout: TimeInterval = 30

    /// PATH and HOME of the CLIs the app starts on this Mac.
    let thisMacEnvironment: [String: String]
    let remoteRunner: RemoteHostCommandRunner

    init(resolver: NativeCLICommandResolver, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        thisMacEnvironment = [
            "PATH": resolver.pathEnvironmentValue,
            "HOME": resolver.inheritedEnvironment["HOME"] ?? NSHomeDirectory(),
        ]
        self.remoteRunner = remoteRunner
    }

    /// Throws `StartCommandCheckError` when the command would not start. Runs processes, and on an SSH host `ssh`,
    /// so call it off the main actor.
    func check(_ command: String, on host: SessionHost) throws {
        switch StartCommandShape(command) {
        case .program(let program):
            try requireProgram(program, on: host)
        case .programKnownOnlyWhenItRuns:
            return
        case .noProgram:
            throw StartCommandCheckError.noProgram
        case .unclosedQuote:
            throw StartCommandCheckError.unclosedQuote
        case .shellOperator(let shellOperator):
            throw StartCommandCheckError.shellOperator(shellOperator)
        }
    }

    private func requireProgram(_ program: String, on host: SessionHost) throws {
        let lookup: (exitStatus: Int32, output: String)?
        switch host {
        case .thisMac:
            lookup = BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: ["-c", Self.lookupScript, "sh", program],
                environment: thisMacEnvironment,
                timeout: Self.thisMacTimeout
            )
        case .ssh(let destination):
            let remoteCommand = RemoteCLICommandBuilder.loginShellCommand(
                "sh -c \(ShellQuoting.quoted(Self.lookupScript)) sh \(ShellQuoting.quoted(program))"
            )
            lookup = remoteRunner.run(destination, remoteCommand, Self.remoteTimeout)
            if lookup?.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
                throw StartCommandCheckError.sshFailed(host: destination)
            }
        }
        guard let lookup else { throw StartCommandCheckError.checkTimedOut(host: host) }
        guard lookup.exitStatus == 0 else { throw StartCommandCheckError.missingProgram(program, host: host) }
    }

    /// POSIX `sh`, so it runs the same whatever the host's login shell is. `~` is the home folder, as in the shell
    /// that starts the CLI.
    static let lookupScript = """
        program=$1
        case $program in
          "~/"*) program=$HOME/${program#"~/"} ;;
        esac
        command -v "$program" >/dev/null 2>&1
        """
}
