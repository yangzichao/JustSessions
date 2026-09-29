import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ConversationStorePollingTests {
    @Test func workRepeatsWhileTheStoreExistsAndStopsOnceItIsGone() async throws {
        let runs = RunCounter()
        var store: ConversationStore? = ConversationStore(adapters: [])
        store?.runPeriodically(every: .milliseconds(10)) { _ in runs.count += 1 }
        try await expectEventually { runs.count >= 3 }

        weak var releasedStore = store
        store = nil
        #expect(releasedStore == nil)
        let runsWhenReleased = runs.count
        try await Task.sleep(for: .milliseconds(50))
        #expect(runs.count == runsWhenReleased)
    }
}

@MainActor
private final class RunCounter {
    var count = 0
}
