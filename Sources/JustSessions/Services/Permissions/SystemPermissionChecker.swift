import UserNotifications

/// Reads each permission's status from macOS without asking for it, so a check never shows a prompt.
struct SystemPermissionChecker: Sendable {
    var fullDiskAccessProbe = FullDiskAccessProbe()
    var accessibilityTrustProbe = AccessibilityTrustProbe()

    func status(of permission: AppPermission) async -> AppPermissionStatus {
        switch permission {
        case .notifications: await notificationStatus()
        case .fullDiskAccess: fullDiskAccessProbe.status()
        case .accessibility: accessibilityTrustProbe.status()
        // macOS has no API that reports it, and only a connection to the local network makes it ask.
        case .localNetwork: .unknown
        }
    }

    private func notificationStatus() async -> AppPermissionStatus {
        guard SessionNotificationCenter.isAvailable else { return .unknown }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return AppPermissionStatus(notificationAuthorization: settings.authorizationStatus)
    }
}

extension AppPermissionStatus {
    init(notificationAuthorization: UNAuthorizationStatus) {
        switch notificationAuthorization {
        case .authorized, .provisional: self = .allowed
        case .denied: self = .notAllowed
        case .notDetermined: self = .notAskedYet
        @unknown default: self = .unknown
        }
    }
}
