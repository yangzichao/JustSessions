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

    /// Copies the host's sessions one tool after another, as `discover(host:)` does. `copying` is told which tool is
    /// next, and `copied` gets that tool's sessions as soon as they are copied, so a slow copy of one tool does not
    /// keep the others' sessions from being listed. Each callback finishes before the copy goes on.
    func discoverToolByTool(
        host: String,
        copying: @Sendable (RemoteSessionCopyStep) async -> Void,
        copied: @Sendable (RemoteSessionCopyStep, [Conversation]) async -> Void
    ) async throws {
        let providers = ConversationProvider.allCases
        for (index, provider) in providers.enumerated() {
            let step = RemoteSessionCopyStep(provider: provider, number: index + 1, count: providers.count)
            await copying(step)
            try mirror.synchronize(host: host, provider: provider)
            await copied(step, try readMirror(host: host, provider: provider))
        }
    }

    func readMirror(host: String) throws -> [Conversation] {
        try ConversationProvider.allCases.flatMap { try readMirror(host: host, provider: $0) }
    }

    func readMirror(host: String, provider: ConversationProvider) throws -> [Conversation] {
        try adapter(for: provider, host: host).discover().map { $0.onHost(.ssh(host)) }
    }

    private func adapter(for provider: ConversationProvider, host: String) -> any ConversationAdapter {
        let directory = mirror.mirrorDirectory(host: host, provider: provider)
        return switch provider {
        case .claude: ClaudeAdapter(configurationDirectory: directory)
        case .codex: CodexAdapter(codexDirectory: directory)
        case .antigravity: AntigravityAdapter(configurationDirectory: directory)
        case .kiro: KiroAdapter(sessionsDirectory: directory)
        case .opencode: OpenCodeAdapter(databaseFile: directory.appendingPathComponent("opencode.db"))
        case .pi: PiAdapter(sessionsDirectory: directory)
        }
    }
}
