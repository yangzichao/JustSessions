import Foundation

extension ConversationStore {
    func startLiveSessionFollowing(interval: Duration = .seconds(1), sources: [any LiveSessionSource] = LiveSessionSources.thisMac()) {
        LiveSessionReporting.ofThePackagedApp?.removeReportsOfExitedProcessesInBackground()
        runPeriodically(every: interval) { await $0.followLiveSessions(sources: sources) }
    }

    func followLiveSessions(sources: [any LiveSessionSource]) async {
        guard !isScanningThisMac, !isDeletingSessions else { return }
        let lookups = terminalSessions.compactMap { tab -> LiveSessionLookup? in
            guard tab.host == .thisMac, tab.isRunning, let provider = tab.provider,
                sources.contains(where: { $0.provider == provider })
            else { return nil }
            return LiveSessionLookup(tabID: tab.id, provider: provider, cliProcessID: tab.knownCLIProcessID)
        }
        guard !lookups.isEmpty else { return }
        let lookedUpProviders = Set(lookups.map(\.provider))
        let listedSessionIDs =
            conversations
            .filter { $0.host == .thisMac && lookedUpProviders.contains($0.provider) }
            .reduce(into: [ConversationProvider: Set<String>]()) { $0[$1.provider, default: []].insert($1.sessionID) }

        let foundSessions = await Task.detached(priority: .utility) {
            lookups.compactMap { lookup -> FoundLiveSession? in
                guard let cliProcessID = lookup.cliProcessID,
                    let source = sources.first(where: { $0.provider == lookup.provider }),
                    let session = source.currentSession(ofCLIProcessID: cliProcessID)
                else { return nil }
                let isListed = listedSessionIDs[lookup.provider]?.contains(session.sessionID) == true
                return FoundLiveSession(
                    tabID: lookup.tabID, sessionID: session.sessionID,
                    isSavedButNotYetListed: !isListed && source.isSaved(session)
                )
            }
        }.value

        var hasSessionToList = false
        for foundSession in foundSessions {
            guard let tab = terminalSessions.first(where: { $0.id == foundSession.tabID }), tab.isRunning,
                tab.conversation?.sessionID != foundSession.sessionID,
                // A branch's CLI may open the session it forks before the fork.
                tab.conversation != nil || foundSession.sessionID != tab.branchedFromSessionID
            else { continue }
            if let conversation = conversations.first(where: {
                $0.provider == tab.provider && $0.host == .thisMac && $0.sessionID == foundSession.sessionID
            }) {
                link(tab, to: conversation)
            } else if foundSession.isSavedButNotYetListed, tab.cliSessionIDRefreshedFor != foundSession.sessionID {
                tab.cliSessionIDRefreshedFor = foundSession.sessionID
                hasSessionToList = true
            }
        }
        if hasSessionToList { refreshThisMac() }
    }
}

private struct LiveSessionLookup: Sendable {
    let tabID: UUID
    let provider: ConversationProvider
    let cliProcessID: Int32?
}

private struct FoundLiveSession: Sendable {
    let tabID: UUID
    let sessionID: String
    let isSavedButNotYetListed: Bool
}
