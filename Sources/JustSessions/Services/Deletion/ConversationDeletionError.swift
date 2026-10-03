import Foundation

enum ConversationDeletionError: LocalizedError, Equatable {
    case invalidSource
    case missingSource
    /// The file is where the session's file should be, but it is no longer that session's file.
    case sourceMismatch
    case activeTerminal
    case codexFailed(String)
    case codexDidNotFinish
    case sourceStillPresent

    var errorDescription: String? {
        switch self {
        case .invalidSource: "The session file is outside the expected history folder. Refresh and try again."
        case .missingSource: "The session file is no longer present. Refresh the conversation list."
        case .sourceMismatch: "The session file no longer matches this session. Refresh and try again."
        case .activeTerminal: "Close this conversation's terminal tab, or end it on its remote host, before deleting it."
        case .codexFailed(let details): "Codex could not delete this session: \(details)"
        case .codexDidNotFinish: "Codex did not finish deleting this session. Refresh and try again."
        case .sourceStillPresent: "Codex reported success, but the session file is still present. Refresh and try again."
        }
    }
}
