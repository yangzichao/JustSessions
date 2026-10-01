import Foundation

enum AntigravityConversationDeletionError: LocalizedError {
    case sessionInUse
    case couldNotCheckProcesses
    case couldNotRestoreFiles

    var errorDescription: String? {
        switch self {
        case .sessionInUse: "This Antigravity session is open in another process. Close its CLI before deleting it."
        case .couldNotCheckProcesses: "Could not check whether Antigravity is using this session. Try deleting it after closing the CLI."
        case .couldNotRestoreFiles: "Deletion failed and some session files remain in the Trash. Restore them before resuming this session."
        }
    }
}
