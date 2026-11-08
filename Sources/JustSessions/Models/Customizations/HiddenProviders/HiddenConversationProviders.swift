import Foundation

/// The CLIs unticked under **Show sessions from** in Settings → General. The app treats them as not installed: their
/// sessions leave the sidebar, its search and filter menu, and New session stops offering them. Their open tabs, and
/// their session files, stay as they are.
struct HiddenConversationProviders: Equatable {
    static let userDefaultsKey = "hiddenSessionProviders"

    private(set) var providers: Set<ConversationProvider>

    init(providers: Set<ConversationProvider> = []) {
        self.providers = providers
    }

    /// Unknown names, such as one a later version saved, are dropped.
    static func load(from userDefaults: UserDefaults) -> HiddenConversationProviders {
        let storedNames = userDefaults.stringArray(forKey: userDefaultsKey) ?? []
        return HiddenConversationProviders(providers: Set(storedNames.compactMap(ConversationProvider.init(rawValue:))))
    }

    /// Sorted, so the same choice saves the same value.
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
