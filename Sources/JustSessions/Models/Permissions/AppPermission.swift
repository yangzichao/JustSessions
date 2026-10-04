import Foundation

/// A macOS permission that part of JustSessions depends on. macOS records each one for the app, also when a CLI
/// running in one of its terminals is what needs it.
enum AppPermission: CaseIterable, Identifiable, Sendable {
    /// For session notifications.
    case notifications
    /// Lets CLIs open files in the folders macOS protects without macOS asking about each folder.
    case fullDiskAccess
    /// For CLIs that reach a device on your network, such as an SSH host at a local address.
    case localNetwork

    var id: Self { self }

    /// The permissions macOS has on this Mac. Local Network privacy came with macOS 15.
    static var onThisMac: [AppPermission] {
        let hasLocalNetworkPrivacy = ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        )
        return allCases.filter { $0 != .localNetwork || hasLocalNetworkPrivacy }
    }

    /// Whether everything works without it, only less smoothly.
    var isOptional: Bool {
        self == .fullDiskAccess
    }
}
