import SwiftUI

extension AppPermission {
    var title: LocalizedStringKey {
        switch self {
        case .notifications: "Notifications"
        case .fullDiskAccess: "Full Disk Access"
        case .accessibility: "Accessibility"
        case .localNetwork: "Local Network"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .notifications:
            "Lets JustSessions tell you when a session needs your input or finishes its turn. Choose which in General."
        case .fullDiskAccess:
            "Optional. Without it, macOS asks about each protected folder, such as Documents or an external drive, the first time a CLI in a terminal opens files there."
        case .accessibility:
            "Optional. Lets CLIs in terminals control apps, such as clicking a menu or typing keys through System Events with osascript. Every CLI in a terminal gets it, so allow it only if you want them to."
        case .localNetwork:
            "JustSessions and the CLIs in its terminals need it to reach a device on your network, such as an SSH host at a local address. macOS doesn't let apps check it, so look for JustSessions in Privacy & Security > Local Network."
        }
    }
}
