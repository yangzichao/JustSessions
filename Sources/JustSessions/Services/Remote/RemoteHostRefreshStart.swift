import Foundation

enum RemoteHostRefreshStart: Equatable {
    enum Refusal: Equatable {
        case workspaceClosing
        case hostNotListed
        case hostDisconnected
        case deferredUntilDeletionEnds
        case alreadyRefreshing
    }

    case started(Task<Void, Never>)
    case refused(Refusal)

    var task: Task<Void, Never>? {
        guard case .started(let task) = self else { return nil }
        return task
    }
}
