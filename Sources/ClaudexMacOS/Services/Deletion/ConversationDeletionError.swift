import Foundation

enum ConversationDeletionError: LocalizedError {
    case invalidSource
    case missingSource
    case activeTerminal
    case codexFailed(String)
    case sourceStillPresent

    var errorDescription: String? {
        switch self {
        case .invalidSource: "The session file is outside the expected history folder. Refresh and try again."
        case .missingSource: "The session file is no longer present. Refresh the conversation list."
        case .activeTerminal: "Close this conversation's terminal tab before deleting it."
        case .codexFailed(let details): "Codex could not delete this session: \(details)"
        case .sourceStillPresent: "Codex reported success, but the session file is still present. Refresh and try again."
        }
    }
}
