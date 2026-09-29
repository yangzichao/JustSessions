import Foundation

/// Lists a remote host's sessions: refreshes the local mirror, then reads it with the regular adapters.
struct RemoteSessionDiscovery: Sendable {
    let mirror: RemoteSessionMirror

    init(mirror: RemoteSessionMirror = RemoteSessionMirror()) {
        self.mirror = mirror
    }

    func discover(host: String) throws -> [Conversation] {
        try mirror.synchronize(host: host)
        return try readMirror(host: host)
    }

    func readMirror(host: String) throws -> [Conversation] {
        let adapters: [any ConversationAdapter] = [
            ClaudeAdapter(configurationDirectory: mirror.mirrorDirectory(host: host, provider: .claude)),
            CodexAdapter(codexDirectory: mirror.mirrorDirectory(host: host, provider: .codex)),
        ]
        return try adapters.flatMap { try $0.discover() }.map { $0.onHost(.ssh(host)) }
    }
}
