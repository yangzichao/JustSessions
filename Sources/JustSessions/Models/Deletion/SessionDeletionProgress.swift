import Combine
import Foundation

@MainActor
final class SessionDeletionProgress: ObservableObject {
    @Published private(set) var completedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var isStopping = false

    var fractionCompleted: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    func start(totalCount: Int) {
        completedCount = 0
        self.totalCount = totalCount
        isStopping = false
    }

    func add(sessionCount: Int) {
        totalCount += sessionCount
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
