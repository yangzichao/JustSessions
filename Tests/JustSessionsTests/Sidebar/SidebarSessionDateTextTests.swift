import Foundation
import Testing
@testable import JustSessions

@MainActor
struct SidebarSessionDateTextTests {
    @Test func spellsDatesExactlyAsTheRowFormattedThem() {
        let cache = SidebarSessionDateText()
        for secondsAgo: TimeInterval in [0, 61.5, 3_600, 90_000, 400 * 24 * 3_600] {
            let date = Date.now.addingTimeInterval(-secondsAgo)
            #expect(cache.text(for: date) == date.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @Test func repeatsOfTheSameDateGetTheSameText() {
        let cache = SidebarSessionDateText()
        let date = Date.now
        #expect(cache.text(for: date) == cache.text(for: date))
    }

    @Test(arguments: [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange])
    func aLocaleOrTimeZoneChangeDropsEveryKeptText(notification: Notification.Name) async throws {
        let notificationCenter = NotificationCenter()
        let cache = SidebarSessionDateText(notificationCenter: notificationCenter)
        _ = cache.text(for: .now)
        #expect(cache.cachedTextCount == 1)

        notificationCenter.post(name: notification, object: nil)

        // The cache empties on the next main run loop turn, where the system posts these notifications from.
        for _ in 0..<100 where cache.cachedTextCount != 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(cache.cachedTextCount == 0)
    }
}
