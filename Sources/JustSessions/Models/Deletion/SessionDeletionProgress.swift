import Combine
import Foundation

/// How far the running deletion has got. Kept apart from `ConversationStore`, so a change re-renders only the
/// progress bar that observes it, not the whole sidebar.
@MainActor
final class SessionDeletionProgress: ObservableObject {
    /// Sessions attempted so far, deleted or not.
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0
    /// Cancel was chosen; the deletion stops after the session it is deleting.
    @Published private(set) var isStopping = false

    var fractionCompleted: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    func start(totalCount: Int) {
        completedCount = 0
        self.totalCount = totalCount
        isStopping = false
    }

    func update(completedCount: Int) {
        guard completedCount != self.completedCount else { return }
        self.completedCount = completedCount
    }

    func markStopping() {
        isStopping = true
    }

    func finish() {
        completedCount = 0
        totalCount = 0
        isStopping = false
    }
}
