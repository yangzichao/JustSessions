import Foundation

final class RemoteHostCLILocations: @unchecked Sendable {
    static let shared = RemoteHostCLILocations()

    private let lock = NSLock()
    private var locationsByHost: [String: [ConversationProvider: RemoteCLILocation]] = [:]

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
