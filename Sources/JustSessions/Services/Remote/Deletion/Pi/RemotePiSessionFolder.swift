import Foundation

enum RemotePiSessionFolder: Equatable {
    case sessionsRoot
    case project(String)

    var projectFolderArgument: String {
        switch self {
        case .sessionsRoot: ""
        case .project(let name): name
        }
    }
}
