import Foundation

enum AntigravityAdapterError: LocalizedError {
    case deletionUnavailable

    var errorDescription: String? {
        "Delete this conversation in Antigravity CLI's interactive session picker."
    }
}
