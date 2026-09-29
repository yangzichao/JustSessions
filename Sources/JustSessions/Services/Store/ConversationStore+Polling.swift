import Foundation

extension ConversationStore {
    /// Calls `work` every `interval`, the first time one interval from now, for as long as the store exists.
    func runPeriodically(every interval: Duration, _ work: @escaping @MainActor (ConversationStore) async -> Void) {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                await work(self)
            }
        }
    }
}
