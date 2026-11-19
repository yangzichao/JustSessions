import Foundation

struct StartCommandCheck: Sendable {
    static let thisMacTimeout: TimeInterval = 10
    static let remoteTimeout: TimeInterval = 30

    let thisMacEnvironment: [String: String]
    let remoteRunner: RemoteHostCommandRunner

    init(resolver: NativeCLICommandResolver, remoteRunner: RemoteHostCommandRunner = RemoteHostCommandRunner()) {
        thisMacEnvironment = [
            "PATH": resolver.pathEnvironmentValue,
            "HOME": resolver.inheritedEnvironment["HOME"] ?? NSHomeDirectory(),
        ]
        self.remoteRunner = remoteRunner
    }

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
                "sh -c \(ShellQuoting.quoted(Self.lookupScript)) sh \(ShellQuoting.quoted(program))",
                on: destination
            )
            lookup = remoteRunner.run(destination, remoteCommand, Self.remoteTimeout)
            if lookup?.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
                throw StartCommandCheckError.sshFailed(host: destination)
            }
        }
        guard let lookup else { throw StartCommandCheckError.checkTimedOut(host: host) }
        guard lookup.exitStatus == 0 else { throw StartCommandCheckError.missingProgram(program, host: host) }
    }

    static let lookupScript = """
        program=$1
        case $program in
          "~/"*) program=$HOME/${program#"~/"} ;;
        esac
        command -v "$program" >/dev/null 2>&1
        """
}
