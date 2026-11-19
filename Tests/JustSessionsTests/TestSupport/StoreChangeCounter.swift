import Foundation
import Observation

@testable import JustSessions

/// Counts changes to the store's observed properties, as `objectWillChange` events counted them before the store was
/// `@Observable`. Each change is counted when it happens; changes made before the counter looks again, within the same
/// main-actor turn, count once, as a view would re-run once for them.
@MainActor
final class StoreChangeCounter {
    private(set) var count = 0
    private let store: ConversationStore
    private let read: (ConversationStore) -> Void
    private var isCounting = true

    /// Counts changes to every property views observe.
    convenience init(_ store: ConversationStore) {
        self.init(store, reading: Self.readObservedProperties(of:))
    }

    /// Counts changes to the properties `read` reads, as a `$property` publisher counted its values after the first.
    init(_ store: ConversationStore, reading read: @escaping (ConversationStore) -> Void) {
        self.store = store
        self.read = read
        observe()
    }

    func cancel() {
        isCounting = false
    }

    private func observe() {
        guard isCounting else { return }
        withObservationTracking {
            read(store)
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isCounting else { return }
                self.count += 1
                Task { @MainActor in self.observe() }
            }
        }
    }

    /// Every property views observe, the former `@Published` ones and the tabs' revision.
    private static func readObservedProperties(of store: ConversationStore) {
        _ = store.conversations
        _ = store.subagentConversations
        _ = store.alert
        _ = store.titleAliases
        _ = store.projectDisplayNames
        _ = store.pinnedItems
        _ = store.messageBookmarks
        _ = store.sidebarProjectList
        _ = store.terminalSessions
        _ = store.tabStateRevision
        _ = store.selectedTerminalID
        _ = store.terminalSplits
        _ = store.pendingDeletionConversationIDs
        _ = store.queuedDeletionConversationIDs
        _ = store.remoteHostList
        _ = store.remoteHostsUsingTmuxPrefix
        _ = store.cliStartCommands
        _ = store.remoteShellStartupChecks
        _ = store.hostsCheckingShellStartup
        _ = store.hostCheck
        _ = store.hostRefreshStatuses
        _ = store.sshHostsNeedingLogIn
        _ = store.sshHostsLoggingIn
        _ = store.sshHostsLoggedIn
        _ = store.remoteSessionCopySteps
        _ = store.tmuxSessionNamesByHost
        _ = store.installedProvidersByHost
        _ = store.detachedCLIActivities
        _ = store.unseenFinishedTurns
        _ = store.waitingForYouStartTimes
    }
}
