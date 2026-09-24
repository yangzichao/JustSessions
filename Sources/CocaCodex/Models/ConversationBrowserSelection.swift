enum ConversationBrowserSelection: Hashable {
    case all
    case recent
    case project(String)
}

enum ConversationProviderFilter: String, CaseIterable, Identifiable {
    case all = "All tools"
    case claude = "Claude Code"
    case codex = "Codex"

    var id: String { rawValue }

    func includes(_ provider: ConversationProvider) -> Bool {
        self == .all || rawValue == provider.rawValue
    }
}
