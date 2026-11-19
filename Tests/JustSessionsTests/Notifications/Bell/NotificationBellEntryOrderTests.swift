import Foundation
import Testing

@testable import JustSessions

struct NotificationBellEntryOrderTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func entry(_ title: String, waitingFor seconds: TimeInterval?) -> NotificationBellEntry {
        NotificationBellEntry(
            source: .detachedTmux(conversationID: title),
            reason: .finishedTurn,
            waitingSince: seconds.map { start.addingTimeInterval(-$0) },
            sessionTitle: title,
            provider: .claude,
            projectName: "project"
        )
    }

    @Test func theWaitThatStartedLastComesFirst() {
        let entries = [Self.entry("Older", waitingFor: 600), Self.entry("Newest", waitingFor: 5), Self.entry("Middle", waitingFor: 60)]

        #expect(entries.sortedNewestFirst().map(\.sessionTitle) == ["Newest", "Middle", "Older"])
    }

    @Test func waitsNotTimedYetComeLast() {
        let entries = [Self.entry("Just moved", waitingFor: nil), Self.entry("Older", waitingFor: 600)]

        #expect(entries.sortedNewestFirst().map(\.sessionTitle) == ["Older", "Just moved"])
    }

    @Test func waitsThatStartedTogetherKeepTitleOrder() {
        let entries = [
            Self.entry("Session 10", waitingFor: 5), Self.entry("Session 9", waitingFor: 5), Self.entry("Apple", waitingFor: nil),
            Self.entry("Banana", waitingFor: nil),
        ]

        #expect(entries.sortedNewestFirst().map(\.sessionTitle) == ["Session 9", "Session 10", "Apple", "Banana"])
    }
}
