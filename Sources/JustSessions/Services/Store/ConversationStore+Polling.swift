import Foundation

extension ConversationStore {
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
