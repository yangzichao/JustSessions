import Foundation

/// Asks Codex's shared background server which threads wait on you. Codex records no approval wait in its session
/// file, but a Codex CLI runs its thread on this server unless it was started with `--no-daemon` or with
/// command-line overrides such as `-c`. A thread the server has not loaded is never waiting here.
final class CodexAppServerWaitReader: @unchecked Sendable {
    let socketPath: String
    private let clientVersion: String
    private let timeout: Duration
    private let retryDelay: Duration
    private let lock = NSLock()
    private var connection: CodexAppServerConnection?
    private var nextTryAfter: ContinuousClock.Instant?

    static func forThisApp() -> CodexAppServerWaitReader? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return CodexAppServerWaitReader(
            codexDirectory: CodexAdapter.defaultCodexDirectory,
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development build"
        )
    }

    /// Codex links the socket of its server from here.
    init(codexDirectory: URL, clientVersion: String, timeout: Duration = .milliseconds(500), retryDelay: Duration = .seconds(5)) {
        socketPath = codexDirectory.appendingPathComponent("app-server-control/app-server-control.sock").path
        self.clientVersion = clientVersion
        self.timeout = timeout
        self.retryDelay = retryDelay
    }

    func threadsWaitingOnYou(among threadIDs: Set<String>) -> Set<String> {
        lock.withLock {
            guard !threadIDs.isEmpty else {
                closeConnection()
                return []
            }
            if let nextTryAfter, ContinuousClock.now < nextTryAfter { return [] }
            do {
                let connection =
                    try self.connection
                    ?? CodexAppServerConnection(socketPath: socketPath, timeout: timeout, clientVersion: clientVersion)
                self.connection = connection
                // A thread the server has not loaded cannot wait on you, so it is not read.
                let loadedThreadIDs = try connection.request("thread/loaded/list", params: [:])?["data"] as? [String] ?? []
                return try threadIDs.intersection(loadedThreadIDs).filter { threadID in
                    let thread = try connection.request("thread/read", params: ["threadId": threadID, "includeTurns": false])?["thread"]
                    return CodexThreadStatus.isWaitingOnYou((thread as? [String: Any])?["status"])
                }
            } catch {
                closeConnection()
                nextTryAfter = .now + retryDelay
                return []
            }
        }
    }

    private func closeConnection() {
        connection?.close()
        connection = nil
    }
}
