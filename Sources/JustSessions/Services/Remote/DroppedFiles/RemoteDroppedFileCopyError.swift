import Foundation

enum RemoteDroppedFileCopyError: LocalizedError, Equatable {
    case couldNotRead(fileName: String)
    case couldNotRun(host: String)
    case sshFailed(host: String, problem: SSHConnectionProblem)
    case couldNotMakeFolder(host: String)
    case couldNotWrite(host: String, fileName: String)
    case incomplete(host: String, fileName: String)
    case stalled(host: String)
    case failed(host: String, output: String)

    var errorDescription: String? {
        switch self {
        case .couldNotRead(let fileName):
            "\(fileName) couldn't be read on this Mac."
        case .couldNotRun(let host):
            "Copying to \(host) did not start."
        case .sshFailed(let host, let problem):
            problem.explanation(host: host)
        case .couldNotMakeFolder(let host):
            "\(host) has no room for dropped files: ~/\(RemoteDroppedFileCopyScript.droppedFilesFolder) couldn't be made."
        case .couldNotWrite(let host, let fileName):
            "\(fileName) couldn't be written on \(host). Its disk may be full."
        case .incomplete(let host, let fileName):
            "Only part of \(fileName) reached \(host). Drop or paste it again."
        case .stalled(let host):
            "\(host) stopped taking the file. Check the connection, then drop or paste it again."
        case .failed(let host, let output):
            "Copying to \(host) failed: \(output)"
        }
    }
}
