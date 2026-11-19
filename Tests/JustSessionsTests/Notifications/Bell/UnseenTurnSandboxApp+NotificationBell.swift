import Foundation
import Testing

@testable import JustSessions

extension UnseenTurnSandboxApp {
    var notificationBellTitles: [String] {
        store.notificationBellEntries.map(\.sessionTitle)
    }

    var notificationBellReasons: [SessionAttentionReason] {
        store.notificationBellEntries.map(\.reason)
    }

    func notificationBellEntry(of title: String) throws -> NotificationBellEntry {
        try #require(store.notificationBellEntries.first { $0.sessionTitle == title }, "The bell does not list \"\(title)\"")
    }

    func clickNotificationBellRow(of title: String) async throws {
        store.showSession(fromNotificationBell: try notificationBellEntry(of: title))
        try await startShownTab(of: title)
    }
}
