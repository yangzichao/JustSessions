import AppKit
import UserNotifications

/// Posts session notifications through macOS, and shows the session when one is clicked. Does nothing when the app
/// runs without its bundle, as under `swift run` or in tests, where macOS has no app to post for.
@MainActor
final class SessionNotificationCenter: NSObject, SessionNotifying {
    static let shared = SessionNotificationCenter()

    private let settingsStore: SessionNotificationSettingsStore
    /// Each window's store, oldest first.
    private let followedStores = NSHashTable<ConversationStore>.weakObjects()

    init(settingsStore: SessionNotificationSettingsStore = .shared) {
        self.settingsStore = settingsStore
    }

    /// Whether the app runs from its bundle, which macOS posts notifications for.
    nonisolated static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var isApplicationActive: Bool {
        NSApp?.isActive ?? false
    }

    /// `JustSessionsAppDelegate` calls this at launch, so clicks on notifications reach the app.
    func startHandlingClicks() {
        guard Self.isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func follow(_ store: ConversationStore) {
        followedStores.add(store)
    }

    func notify(_ notification: SessionNotification) {
        guard Self.isAvailable, settingsStore.preferences.allows(notification.reason) else { return }
        Task.detached(priority: .utility) { await Self.post(notification) }
    }

    /// Asks for permission the first time. macOS asks you once and gives the same answer from then on, so a
    /// notification you turned off in System Settings is dropped here.
    nonisolated private static func post(_ notification: SessionNotification) async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle
        content.body = notification.body
        content.sound = .default
        content.userInfo = notification.source.userInfo
        let request = UNNotificationRequest(
            identifier: notification.source.notificationIdentifier,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Shows macOS's prompt if it hasn't asked yet, and returns whether notifications are allowed.
    nonisolated static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true
    }

    /// Shows the session in the window whose tab runs it, or else reattaches to it in the first window.
    func showSession(notifiedAbout source: SessionAttentionSource) {
        let stores = followedStores.allObjects
        if stores.contains(where: { $0.showTab(notifiedAbout: source) }) { return }
        stores.first?.reattach(notifiedAbout: source)
    }
}

extension SessionNotificationCenter: UNUserNotificationCenterDelegate {
    /// The store only notifies about sessions out of view, so a notification shows even while the app is in front.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let source = SessionAttentionSource(userInfo: response.notification.request.content.userInfo) else { return }
        await showSession(notifiedAbout: source)
    }
}
