import AppKit
import UserNotifications

/// Posts session notifications through macOS, and shows the session when one is clicked. Does nothing when the app
/// runs without its bundle, as under `swift run` or in tests, where macOS has no app to post for.
@MainActor
final class SessionNotificationCenter: NSObject, SessionNotifying {
    static let shared = SessionNotificationCenter()

    private let settingsStore: SessionNotificationSettingsStore
    private let windowRegistry: WorkspaceWindowRegistry

    init(settingsStore: SessionNotificationSettingsStore = .shared, windowRegistry: WorkspaceWindowRegistry = .shared) {
        self.settingsStore = settingsStore
        self.windowRegistry = windowRegistry
    }

    nonisolated static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var isApplicationActive: Bool {
        NSApp?.isActive ?? false
    }

    func startHandlingClicks() {
        guard Self.isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func notify(_ notification: SessionNotification) {
        guard Self.isAvailable, settingsStore.preferences.allows(notification.reason) else { return }
        Task.detached(priority: .utility) { await Self.post(notification) }
    }

    func notifySignInNeeded(on host: String) {
        guard Self.isAvailable, settingsStore.preferences.allows(.needsInput(reason: nil)) else { return }
        let title = AppLocalization.string("Sign in on \(host)")
        let body = AppLocalization.string("Your sign-in command on this host is due. Click to sign in.")
        Task.detached(priority: .utility) {
            guard await Self.requestAuthorization() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = [Self.signInHostKey: host]
            let request = UNNotificationRequest(identifier: "\(Self.signInHostKey).\(host)", content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated static let signInHostKey = "signInHost"

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

    nonisolated static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true
    }

    func showSession(notifiedAbout source: SessionAttentionSource) {
        windowRegistry.showSession(wantingAttention: source)
    }
}

extension SessionNotificationCenter: UNUserNotificationCenterDelegate {
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
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let userInfo = response.notification.request.content.userInfo
        if let host = userInfo[Self.signInHostKey] as? String {
            await RemoteSignIns.shared.signInFromNotification(on: host)
            return
        }
        guard let source = SessionAttentionSource(userInfo: userInfo) else { return }
        await showSession(notifiedAbout: source)
    }
}
