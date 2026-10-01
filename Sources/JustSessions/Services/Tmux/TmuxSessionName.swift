import Foundation

/// Names of the tmux sessions tabs run their CLI in, on this Mac and on SSH hosts. A session's own tab uses a name
/// derived from its session id, so resuming it again reattaches instead of starting a second CLI on the same session.
enum TmuxSessionName {
    static let prefix = "justsessions-"

    static func forConversation(_ conversation: Conversation) -> String {
        forSession(provider: conversation.provider, sessionID: conversation.sessionID)
    }

    static func forSession(provider: ConversationProvider, sessionID: String) -> String {
        "\(prefix)\(provider.executableName)-\(sessionID)"
    }

    /// A new session or a branch has no session id of its own yet.
    static func unique(for provider: ConversationProvider) -> String {
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(prefix)\(provider.executableName)-new-\(suffix)"
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
