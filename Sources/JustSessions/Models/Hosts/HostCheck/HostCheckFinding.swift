import Foundation

/// One thing Check this host… looked at on an SSH host: what it means for JustSessions, what the host itself printed,
/// and a command to run in your own terminal, so a problem on the host can be seen without JustSessions.
struct HostCheckFinding: Codable, Equatable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable {
        /// Works as JustSessions needs it to.
        case passed
        /// Worth knowing; needs nothing.
        case note
        /// Works, with a limit the summary names.
        case warning
        /// Keeps part of JustSessions from working on the host.
        case problem
    }

    let id: HostCheckFindingID
    let status: Status
    let title: String
    let summary: String
    /// What the host printed, as it printed it; nil when there is nothing to show.
    var hostOutput: String? = nil
    /// Does what the check did, for Terminal; nil when there is no single command for it.
    var commandToRunYourself: String? = nil
}
