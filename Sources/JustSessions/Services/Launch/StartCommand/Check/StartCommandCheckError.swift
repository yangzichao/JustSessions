import Foundation

enum StartCommandCheckError: LocalizedError, Equatable {
    case unclosedQuote
    case shellOperator(String)
    case noProgram
    case missingProgram(String, host: SessionHost)
    case checkTimedOut(host: SessionHost)
    case sshFailed(host: String)

    var errorDescription: String? {
        switch self {
        case .unclosedQuote:
            "A quote or parenthesis in the start command isn't closed."
        case .shellOperator(let shellOperator):
            "The start command can't contain \(shellOperator). JustSessions adds its own arguments after it, so it has to be a single command; put anything more in a script and start that."
        case .noProgram:
            "The start command doesn't name a program to run."
        case .missingProgram(let program, .thisMac):
            "There is no program \(program) on this Mac."
        case .missingProgram(let program, .ssh(let destination)):
            "There is no program \(program) on \(destination)."
        case .checkTimedOut(.thisMac):
            "Checking the start command did not finish within \(Int(StartCommandCheck.thisMacTimeout)) seconds."
        case .checkTimedOut(.ssh(let destination)):
            "Checking the start command on \(destination) did not finish within \(Int(StartCommandCheck.remoteTimeout)) seconds."
        case .sshFailed(let host):
            "Could not connect to \(host). Check that `ssh \(host)` works in Terminal without a password prompt."
        }
    }
}
