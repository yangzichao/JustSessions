import Foundation

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
