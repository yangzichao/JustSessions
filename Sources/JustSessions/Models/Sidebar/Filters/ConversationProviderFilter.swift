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

    var provider: ConversationProvider? {
        switch self {
        case .all: nil
        case .only(let provider): provider
        }
    }

    func includes(_ provider: ConversationProvider) -> Bool {
        self == .all || self == .only(provider)
    }

    static func choices(offering providers: Set<ConversationProvider>, selected: ConversationProviderFilter) -> [ConversationProviderFilter]
    {
        [.all]
            + ConversationProvider.allCases
            .filter { providers.contains($0) || selected == .only($0) }
            .map(ConversationProviderFilter.only)
    }
}
