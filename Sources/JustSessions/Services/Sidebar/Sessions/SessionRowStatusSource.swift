import Foundation

enum SessionRowStatusSource {
    case tab(TerminalSession)
    case detachedCLI(SessionRunStatus)

    @MainActor var status: SessionRunStatus {
        switch self {
        case .tab(let tab): tab.runStatus
        case .detachedCLI(let status): status
        }
    }
}
