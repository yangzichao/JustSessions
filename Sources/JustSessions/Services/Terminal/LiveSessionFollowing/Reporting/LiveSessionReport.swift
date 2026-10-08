import Foundation

/// What a Pi or OpenCode CLI last reported through the app's extension; see `LiveSessionReporting`.
struct LiveSessionReport: Sendable, Equatable {
    /// Nil while the CLI shows no session, as on OpenCode's home screen.
    let sessionID: String?
    /// The file Pi keeps the session in; it appears only after the session's first prompt.
    let sessionFile: URL?
    /// Nil from a CLI too old to tell, and while it shows no session.
    let activity: CLIActivity?

    /// Nil unless the report is one the process with this id wrote.
    init?(jsonData: Data, processID: Int32) {
        guard let object = ConversationMetadata.object(from: jsonData),
              (object["pid"] as? NSNumber)?.int32Value == processID else { return nil }
        sessionID = object["sessionId"] as? String
        sessionFile = (object["sessionFile"] as? String).flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
        activity = sessionID == nil ? nil : Self.activity(from: object)
    }

    /// The extensions write `activity` "working", "waiting" with `waitingFor` saying on what, or "idle".
    private static func activity(from object: [String: Any]) -> CLIActivity? {
        switch object["activity"] as? String {
        case "working": .working
        case "waiting": .needsInput(reportedReason: object["waitingFor"] as? String)
        case "idle": .idle
        default: nil
        }
    }
}
