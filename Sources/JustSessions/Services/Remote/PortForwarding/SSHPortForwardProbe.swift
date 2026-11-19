import Foundation

enum SSHPortForwardProbe: Equatable {
    case couldNotStart
    case reachedPort
    case stillOpenAtTimeout
    case failed(output: String)

    static let timeout: TimeInterval = 3

    static func run(_ forward: SSHPortForward, controlPath: String, sshExecutable: String) -> SSHPortForwardProbe {
        let outcome = BoundedProcessRunner.outcome(
            ofExecutable: sshExecutable,
            arguments: SSHPortForwardCommands.probeArguments(forward, controlPath: controlPath),
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: timeout
        )
        guard let outcome else { return .couldNotStart }
        switch outcome.exitStatus {
        case nil: return .stillOpenAtTimeout
        case 0: return .reachedPort
        default: return .failed(output: outcome.output)
        }
    }
}
