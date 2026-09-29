import Foundation

enum RemoteFolderResolutionError: LocalizedError, Equatable {
    case couldNotRun(host: String)
    case sshFailed(host: String)
    case missingFolder(host: String, folder: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRun(let host):
            "Looking up the folder on \(host) did not finish within 30 seconds."
        case .sshFailed(let host):
            "Could not connect to \(host). Check that `ssh \(host)` works in Terminal without a password prompt."
        case .missingFolder(let host, let folder):
            "There is no folder \(folder) on \(host)."
        }
    }
}
