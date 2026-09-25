import Foundation

enum SessionRecencyFilter: Hashable {
    case all
    case recent

    static let recentInterval: TimeInterval = 7 * 24 * 60 * 60

    func includes(_ conversation: Conversation, now: Date = .now) -> Bool {
        self == .all || conversation.updatedAt >= now.addingTimeInterval(-Self.recentInterval)
    }
}

enum ConversationProviderFilter: String, CaseIterable, Identifiable {
    case all = "All tools"
    case claude = "Claude Code"
    case codex = "Codex"
    case antigravity = "Antigravity"

    var id: String { rawValue }

    /// The one tool this filter keeps, or nil when it keeps all of them.
    var provider: ConversationProvider? { ConversationProvider(rawValue: rawValue) }

    func includes(_ provider: ConversationProvider) -> Bool {
        self == .all || rawValue == provider.rawValue
    }
}
