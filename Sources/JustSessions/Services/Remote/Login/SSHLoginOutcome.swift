import Foundation

enum SSHLoginOutcome: Equatable, Sendable {
    case loggedIn
    case cancelled
    case failed(SSHConnectionProblem)
}
