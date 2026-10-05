import Foundation

/// Says which session a tool's running CLI on this Mac is in now. A CLI moves to another session without its tab
/// knowing, as with `/new`, `/clear`, or `/resume`; see `followLiveSessions`. Lookups run off the main actor.
protocol LiveSessionSource: Sendable {
    var provider: ConversationProvider { get }

    /// The session the CLI with this process id is in; nil when it is in none yet or does not say.
    func currentSession(ofCLIProcessID processID: Int32) -> LiveCLISession?

    /// Whether the tool has saved the session where a refresh of this Mac finds it.
    func isSaved(_ session: LiveCLISession) -> Bool
}

/// The session a CLI is in, as a `LiveSessionSource` read it.
struct LiveCLISession: Sendable, Equatable {
    let sessionID: String
    /// The file the tool keeps the session in, when it is known; it may not exist until the tool saves the session.
    let file: URL?
}
