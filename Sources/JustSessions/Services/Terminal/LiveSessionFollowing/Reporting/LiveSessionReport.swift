import Foundation

/// What a Pi or OpenCode CLI last reported through the app's extension; see `LiveSessionReporting`.
struct LiveSessionReport: Sendable, Equatable {
    /// Nil while the CLI shows no session, as on OpenCode's home screen.
    let sessionID: String?
    /// The file Pi keeps the session in; it appears only after the session's first prompt.
    let sessionFile: URL?

    /// Nil unless the report is one the process with this id wrote.
    init?(jsonData: Data, processID: Int32) {
        guard let object = ConversationMetadata.object(from: jsonData),
              (object["pid"] as? NSNumber)?.int32Value == processID else { return nil }
        sessionID = object["sessionId"] as? String
        sessionFile = (object["sessionFile"] as? String).flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
    }
}
