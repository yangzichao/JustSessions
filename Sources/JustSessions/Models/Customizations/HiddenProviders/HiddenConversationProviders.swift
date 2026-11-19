import Foundation

struct HiddenConversationProviders: Equatable {
    static let userDefaultsKey = "hiddenSessionProviders"

    private(set) var providers: Set<ConversationProvider>

    init(providers: Set<ConversationProvider> = []) {
        self.providers = providers
    }

    static func load(from userDefaults: UserDefaults) -> HiddenConversationProviders {
        let storedNames = userDefaults.stringArray(forKey: userDefaultsKey) ?? []
        return HiddenConversationProviders(providers: Set(storedNames.compactMap(ConversationProvider.init(rawValue:))))
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(providers.map(\.rawValue).sorted(), forKey: Self.userDefaultsKey)
    }

    var isEmpty: Bool { providers.isEmpty }

    func hides(_ provider: ConversationProvider) -> Bool {
        providers.contains(provider)
    }

    mutating func setHidden(_ isHidden: Bool, provider: ConversationProvider) {
        if isHidden {
            providers.insert(provider)
        } else {
            providers.remove(provider)
        }
    }
}
