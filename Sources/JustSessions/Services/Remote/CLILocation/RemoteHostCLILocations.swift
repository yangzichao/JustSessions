import Foundation

/// Each SSH host's CLI locations from its last refresh. The store sets them, and command builders on any thread read
/// them, as they read `RemoteHostShellStartups`.
final class RemoteHostCLILocations: @unchecked Sendable {
    static let shared = RemoteHostCLILocations()

    private let lock = NSLock()
    private var locationsByHost: [String: [ConversationProvider: RemoteCLILocation]] = [:]

    /// Where a tab starts the tool's CLI: by name in the login shell, unless a refresh found it only in an install
    /// folder. A host not refreshed since launch, or whose refresh didn't find the CLI, starts it by name, so a
    /// missing CLI is reported in the tab.
    func location(of provider: ConversationProvider, on host: String) -> RemoteCLILocation {
        lock.withLock { locationsByHost[host]?[provider] } ?? .loginShell
    }

    func setLocations(_ locations: [ConversationProvider: RemoteCLILocation], on host: String) {
        lock.withLock { locationsByHost[host] = locations }
    }

    func forgetLocations(on host: String) {
        _ = lock.withLock { locationsByHost.removeValue(forKey: host) }
    }
}
