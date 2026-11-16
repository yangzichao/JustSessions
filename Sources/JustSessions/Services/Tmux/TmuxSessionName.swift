import Foundation

/// Names of the tmux sessions tabs run their CLI or shell in, on this Mac and on SSH hosts. A session's own tab uses a
/// name derived from its session id, so resuming it again reattaches instead of starting a second CLI on the same
/// session. A plain terminal's name is its tab's own, kept with the tab across launches.
enum TmuxSessionName {
    static let prefix = "justsessions-"
    /// No CLI's executable is named `terminal`, so these names never name a session.
    static let plainTerminalPrefix = "\(prefix)terminal-"

    static func forConversation(_ conversation: Conversation) -> String {
        forSession(provider: conversation.provider, sessionID: conversation.sessionID)
    }

    static func forSession(provider: ConversationProvider, sessionID: String) -> String {
        "\(prefix)\(provider.executableName)-\(sessionID)"
    }

    /// A new session or a branch has no session id of its own yet.
    static func unique(for provider: ConversationProvider) -> String {
        "\(prefix)\(provider.executableName)-new-\(randomSuffix())"
    }

    /// A new plain terminal's, which its tab keeps; see `ReopenableTerminalTab.tmuxSessionName`.
    static func forNewPlainTerminal() -> String {
        "\(plainTerminalPrefix)\(randomSuffix())"
    }

    static func isPlainTerminal(named name: String) -> Bool {
        name.hasPrefix(plainTerminalPrefix)
    }

    private static func randomSuffix() -> String {
        UUID().uuidString.prefix(8).lowercased()
    }

    /// The session whose own name this is; nil for a new session's temporary name and for other names.
    static func session(named name: String) -> (provider: ConversationProvider, sessionID: String)? {
        for provider in ConversationProvider.allCases {
            let providerPrefix = "\(prefix)\(provider.executableName)-"
            guard name.hasPrefix(providerPrefix) else { continue }
            let sessionID = String(name.dropFirst(providerPrefix.count))
            return provider.isValidSessionID(sessionID) ? (provider, sessionID) : nil
        }
        return nil
    }

    /// Session names from `list-sessions`. Lines a shell profile prints, and sessions not started here, are ignored.
    static func appSessionNames(inListOutput output: String) -> Set<String> {
        Set(output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(prefix) && !$0.contains(" ") })
    }
}
