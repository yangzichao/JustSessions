import Foundation

enum CLIActivity: Equatable, Sendable {
    case working
    case needsInput(reason: String?)
    case idle

    static let maximumWaitReasonLength = 60

    /// Waiting on you for what the CLI says, on one line and shortened; no reason when it says nothing. A Pi
    /// extension's prompt title can span lines.
    static func needsInput(reportedReason: String?) -> CLIActivity {
        let reason = (reportedReason ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return .needsInput(reason: reason.isEmpty ? nil : String(reason.prefix(maximumWaitReasonLength)))
    }
}
