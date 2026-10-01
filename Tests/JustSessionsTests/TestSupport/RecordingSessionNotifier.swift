import Foundation
@testable import JustSessions

/// Stands in for macOS notifications: keeps what the store would post.
@MainActor
final class RecordingSessionNotifier: SessionNotifying {
    var isApplicationActive = false
    private(set) var notifications: [SessionNotification] = []

    func notify(_ notification: SessionNotification) {
        notifications.append(notification)
    }

    func follow(_ store: ConversationStore) {}
}
