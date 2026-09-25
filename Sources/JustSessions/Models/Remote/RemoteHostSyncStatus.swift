import Foundation

/// Where the last copy of a remote host's session files stands.
enum RemoteHostSyncStatus: Equatable {
    case syncing
    case synced(Date)
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
