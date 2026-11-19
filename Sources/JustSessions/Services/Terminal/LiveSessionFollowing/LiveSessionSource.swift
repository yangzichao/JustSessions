import Foundation

protocol LiveSessionSource: Sendable {
    var provider: ConversationProvider { get }

    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession?

    func isSaved(_ session: LiveCLISession) -> Bool
}

struct LiveCLISession: Sendable, Equatable {
    let sessionID: String
    let file: URL?
}
