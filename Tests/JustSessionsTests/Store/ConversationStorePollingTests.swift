import Foundation
import Testing
@testable import JustSessions

@MainActor
struct ConversationStorePollingTests {
    @Test func workRepeatsWhileTheStoreExistsAndStopsOnceItIsGone() async throws {
        let runs = RunCounter()
        var store: ConversationStore? = ConversationStore(adapters: [], startsBackgroundPolling: false)
        store?.runPeriodically(every: .milliseconds(10)) { _ in runs.count += 1 }
        // While the suite starts, its window tests keep the main actor busy for half a minute or more on shared CI
        // runners: the v1.0.8 release run saw 33 seconds before three 10 ms timer deliveries. A passing run waits
        // only for those deliveries.
        try await expectEventually(timeout: .seconds(120)) { runs.count >= 3 }

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
