import AppKit

extension AppPermission {
    /// The System Settings page where the permission is turned on or off.
    var systemSettingsURL: URL? {
        switch self {
        case .notifications:
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "dev.zichaoyang.justsessions"
            return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)")
        case .fullDiskAccess:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .localNetwork:
            // System Settings has no link to the Local Network list itself, only to Privacy & Security.
            return URL(string: "x-apple.systempreferences:com.apple.preference.security")
        }
    }

    func openSystemSettings() {
        guard let systemSettingsURL else { return }
        NSWorkspace.shared.open(systemSettingsURL)
    }
}
