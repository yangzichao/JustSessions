import Foundation

enum ConversationProviderFilter: Hashable, Identifiable {
    case all
    case only(ConversationProvider)

    var id: String { title }

    var title: String {
        switch self {
        case .all: "All tools"
        case .only(let provider): provider.rawValue
        }
    }

    /// The one tool this filter keeps, or nil when it keeps all of them.
    var provider: ConversationProvider? {
        switch self {
        case .all: nil
        case .only(let provider): provider
        }
    }

    func includes(_ provider: ConversationProvider) -> Bool {
        self == .all || self == .only(provider)
    }

    /// "All tools", then one filter per tool offered, in the tools' usual order. The selected filter stays listed
    /// even when its tool is no longer offered, so the menu always shows what filters the list.
    static func choices(offering providers: Set<ConversationProvider>, selected: ConversationProviderFilter) -> [ConversationProviderFilter] {
        [.all] + ConversationProvider.allCases
            .filter { providers.contains($0) || selected == .only($0) }
            .map(ConversationProviderFilter.only)
    }
}
