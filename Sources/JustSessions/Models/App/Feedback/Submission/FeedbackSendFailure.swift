import Foundation

/// Why feedback was not stored, from the Worker's `result` or the connection to it.
enum FeedbackSendFailure: Error, Equatable {
    /// Empty, too long, or not what the app sends.
    case invalidFeedback
    /// Turnstile did not accept the token; a new check can be sent.
    case verificationFailed
    case tooManyRequests
    /// The Worker could not check or store it, or answered something unexpected.
    case unavailable
    /// The Worker could not be reached.
    case unreachable

    /// The failure the Worker's `result` names, or nil for "sent".
    init?(workerResult: String?) {
        switch workerResult {
        case "sent": return nil
        case "invalid-feedback": self = .invalidFeedback
        case "verification-failed": self = .verificationFailed
        case "too-many-requests": self = .tooManyRequests
        default: self = .unavailable
        }
    }
}
