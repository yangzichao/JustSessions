import Foundation

/// New sessions offer only the tools whose CLI the host has. Each host is checked when it refreshes.
extension ConversationStore {
    func setInstalledProviders(_ providers: Set<ConversationProvider>, on host: SessionHost) {
        guard hosts.contains(host), installedProvidersByHost[host] != providers else { return }
        installedProvidersByHost[host] = providers
    }

    /// The tools a new session on the host can start, in their usual order. Until the host's first check, every
    /// tool that runs there, so a CLI that is missing is reported when it is started rather than hidden.
    func newSessionProviders(on host: SessionHost) -> [ConversationProvider] {
        let runnableProviders = ConversationProvider.allCases.filter { $0.runs(on: host) }
        guard let installedProviders = installedProvidersByHost[host] else { return runnableProviders }
        return runnableProviders.filter(installedProviders.contains)
    }

    /// Each host's new-session tools, for views that let the host be picked.
    var newSessionProvidersByHost: [SessionHost: [ConversationProvider]] {
        Dictionary(uniqueKeysWithValues: hosts.map { ($0, newSessionProviders(on: $0)) })
    }

    /// The tools the sidebar's filter offers: those installed on some host, and those with listed sessions.
    var filterableProviders: Set<ConversationProvider> {
        Set(installedProvidersByHost.values.joined()).union(conversations.map(\.provider))
    }
}
