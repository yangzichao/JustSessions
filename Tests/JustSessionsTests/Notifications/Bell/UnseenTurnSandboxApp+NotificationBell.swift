import Foundation
import Testing

@testable import JustSessions

/// The window's notification bell, as the sidebar header shows it.
extension UnseenTurnSandboxApp {
    /// The sessions the bell lists, top to bottom, by title.
    var notificationBellTitles: [String] {
        store.notificationBellEntries.map(\.sessionTitle)
    }

    var notificationBellReasons: [SessionAttentionReason] {
        store.notificationBellEntries.map(\.reason)
    }

    func notificationBellEntry(of title: String) throws -> NotificationBellEntry {
        try #require(store.notificationBellEntries.first { $0.sessionTitle == title }, "The bell does not list \"\(title)\"")
    }

    /// Clicks the session's row in the bell, and waits until the tab that shows it runs, as `clickRow(of:)` does.
    func clickNotificationBellRow(of title: String) async throws {
        store.showSession(fromNotificationBell: try notificationBellEntry(of: title))
        try await startShownTab(of: title)
    }
}
