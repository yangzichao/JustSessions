import Foundation

extension ConversationStore {
    func setInstalledProviders(_ providers: Set<ConversationProvider>, on host: SessionHost) {
        guard hosts.contains(host), installedProvidersByHost[host] != providers else { return }
        installedProvidersByHost[host] = providers
    }

    func newSessionProviders(on host: SessionHost) -> [ConversationProvider] {
        let shownProviders = ConversationProvider.allCases.filter { !hiddenConversationProviders.hides($0) }
        guard let installedProviders = installedProvidersByHost[host] else { return shownProviders }
        return shownProviders.filter(installedProviders.contains)
    }

    var newSessionProvidersByHost: [SessionHost: [ConversationProvider]] {
        Dictionary(uniqueKeysWithValues: hosts.map { ($0, newSessionProviders(on: $0)) })
    }

    var filterableProviders: Set<ConversationProvider> {
        Set(installedProvidersByHost.values.joined())
            .union(conversations.map(\.provider))
            .subtracting(hiddenConversationProviders.providers)
    }
}
