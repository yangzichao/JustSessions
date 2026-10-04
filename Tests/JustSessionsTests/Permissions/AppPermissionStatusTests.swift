import Foundation
import Testing
import UserNotifications
@testable import JustSessions

struct AppPermissionStatusTests {
    @Test func notificationAuthorizationMapsToAStatus() {
        #expect(AppPermissionStatus(notificationAuthorization: .authorized) == .allowed)
        #expect(AppPermissionStatus(notificationAuthorization: .provisional) == .allowed)
        #expect(AppPermissionStatus(notificationAuthorization: .denied) == .notAllowed)
        #expect(AppPermissionStatus(notificationAuthorization: .notDetermined) == .notAskedYet)
    }

    @Test func localNetworkIsListedFromMacOS15On() {
        let hasLocalNetworkPrivacy = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15
        #expect(AppPermission.onThisMac.contains(.localNetwork) == hasLocalNetworkPrivacy)
        #expect(AppPermission.onThisMac.contains(.notifications))
        #expect(AppPermission.onThisMac.contains(.fullDiskAccess))
    }

    @Test func checkingNeverReportsLocalNetwork() async {
        #expect(await SystemPermissionChecker().status(of: .localNetwork) == .unknown)
    }

    @Test func eachPermissionOpensItsSystemSettingsPage() {
        #expect(AppPermission.fullDiskAccess.systemSettingsURL?.absoluteString
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        #expect(AppPermission.notifications.systemSettingsURL?.absoluteString
            .hasPrefix("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=") == true)
        #expect(AppPermission.localNetwork.systemSettingsURL != nil)
    }
}
