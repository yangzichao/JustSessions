import Foundation

enum TmuxSessionName {
    static let prefix = "justsessions-"
    static let plainTerminalPrefix = "\(prefix)terminal-"

    static func forConversation(_ conversation: Conversation) -> String {
        forSession(provider: conversation.provider, sessionID: conversation.sessionID)
    }

    static func forSession(provider: ConversationProvider, sessionID: String) -> String {
        "\(prefix)\(provider.executableName)-\(sessionID)"
    }

    static func unique(for provider: ConversationProvider) -> String {
        "\(prefix)\(provider.executableName)-new-\(randomSuffix())"
    }

    static func forNewPlainTerminal() -> String {
        "\(plainTerminalPrefix)\(randomSuffix())"
    }

    static func isPlainTerminal(named name: String) -> Bool {
        name.hasPrefix(plainTerminalPrefix)
    }

    private static func randomSuffix() -> String {
        UUID().uuidString.prefix(8).lowercased()
    }

    static func session(named name: String) -> (provider: ConversationProvider, sessionID: String)? {
        guard !isPlainTerminal(named: name) else { return nil }
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
        Set(
            output
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix(prefix) && !$0.contains(" ") })
    }
}
