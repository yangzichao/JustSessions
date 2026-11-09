import AppKit

/// Reconnects SSH tabs whose connection dropped, as when the Mac slept with its lid closed, so they show again the
/// CLI that kept running in tmux on the host. A dropped tab waits until its host lists the tab's tmux session, and is
/// then reconnected in its place in every window, as Reconnect does. A tab whose session the host no longer lists
/// stays ended, since its CLI ended too; it is never started again on its own. A host that can't be asked, or needs
/// Connect…, is asked again as `RemoteTabReconnectSchedule` says, and at once when the Mac wakes, the app comes
/// forward, or a login to it opens.
@MainActor
final class RemoteTabReconnector {
    static let shared = RemoteTabReconnector()

    /// Posted by a tab whose connection dropped; its object is the tab. See `TerminalSession.hasDroppedConnectionToTmux`.
    static let connectionDroppedNotification = Notification.Name("JustSessions.RemoteTabConnectionDropped")
    /// Posted once Connect… logs in; its object is the host.
    static let loginOpenedNotification = Notification.Name("JustSessions.SSHLoginOpened")

    /// A tab this reconnected that drops again this soon is left ended, so a connection that keeps failing is not
    /// reconnected over and over. The Mac waking, the app coming forward, or a login opening tries it again.
    static let shortestRunBeforeReconnectingAgain: TimeInterval = 60

    private let registry: WorkspaceWindowRegistry
    /// The JustSessions tmux sessions running on the host, or nil when it couldn't be asked. Runs off the main actor.
    private let listTmuxSessions: @Sendable (String) -> Set<String>?
    private let currentDate: () -> Date
    /// Whether it asks each host once due on its own; tests ask with `askDueHosts()` instead.
    private let wakesItselfUp: Bool
    private var schedule = RemoteTabReconnectSchedule()
    private var hostsBeingAsked: Set<String> = []
    /// Tabs whose CLI the host no longer ran when asked.
    private var tabsWhoseCLIEnded: Set<UUID> = []
    /// When this reconnected each tab it made, by the new tab's id.
    private var reconnectedAtByTab: [UUID: Date] = [:]
    private var wakeUp: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    init(
        registry: WorkspaceWindowRegistry = .shared,
        listTmuxSessions: @escaping @Sendable (String) -> Set<String>? = {
            RemoteHostStatusProbe.status(ofHost: $0)?.tmuxSessionNames
        },
        currentDate: @escaping () -> Date = Date.init,
        wakesItselfUp: Bool = true
    ) {
        self.registry = registry
        self.listTmuxSessions = listTmuxSessions
        self.currentDate = currentDate
        self.wakesItselfUp = wakesItselfUp
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.tryAgain() }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tryAgain() }
            },
            center.addObserver(forName: Self.connectionDroppedNotification, object: nil, queue: .main) { [weak self] notification in
                guard let tab = notification.object as? TerminalSession else { return }
                MainActor.assumeIsolated { self?.tabDropped(tab) }
            },
            center.addObserver(forName: Self.loginOpenedNotification, object: nil, queue: .main) { [weak self] notification in
                guard let host = notification.object as? String else { return }
                MainActor.assumeIsolated { self?.tryAgain(onlyOn: host) }
            },
        ]
    }

    /// Whether the host is being asked now; its answer hasn't come yet.
    func isAsking(_ host: String) -> Bool {
        hostsBeingAsked.contains(host)
    }

    func tabDropped(_ tab: TerminalSession) {
        guard tab.hasDroppedConnectionToTmux, let host = tab.host.sshDestination else { return }
        let now = currentDate()
        if let reconnectedAt = reconnectedAtByTab[tab.id],
           now.timeIntervalSince(reconnectedAt) < Self.shortestRunBeforeReconnectingAgain { return }
        tab.isWaitingToReconnect = true
        schedule.startTrying(host, now: now)
        scheduleWakeUp()
    }

    /// Tries every dropped tab again whose CLI wasn't found ended, also one whose tries gave up, on every host or only
    /// on `onlyOn`.
    func tryAgain(onlyOn onlyHost: String? = nil) {
        let now = currentDate()
        let tabs = registry.stores.flatMap(\.terminalSessions)
        let openTabIDs = Set(tabs.map(\.id))
        tabsWhoseCLIEnded.formIntersection(openTabIDs)
        reconnectedAtByTab = reconnectedAtByTab.filter { openTabIDs.contains($0.key) }
        var hosts: Set<String> = []
        for tab in tabs where tab.hasDroppedConnectionToTmux && !tabsWhoseCLIEnded.contains(tab.id) {
            guard let host = tab.host.sshDestination, onlyHost == nil || host == onlyHost else { continue }
            tab.isWaitingToReconnect = true
            hosts.insert(host)
        }
        for host in hosts { schedule.startTrying(host, now: now) }
        pruneHostsWithoutCandidates()
        scheduleWakeUp()
    }

    /// Asks each host that is due, unless it is being asked already or needs Connect…, which counts as a failure. A
    /// host that was removed or disconnected from is given up.
    func askDueHosts() {
        pruneHostsWithoutCandidates()
        let now = currentDate()
        for host in schedule.hostsBeingTried where schedule.isDue(host, now: now) && !hostsBeingAsked.contains(host) {
            guard let oldestStore = registry.stores.first, oldestStore.remoteHostList.hosts.contains(host),
                  !oldestStore.isDisconnected(host) else {
                stopTrying(host)
                continue
            }
            if registry.stores.contains(where: { $0.sshHostsNeedingLogIn.contains(host) }) {
                noteFailure(on: host)
                continue
            }
            hostsBeingAsked.insert(host)
            let generation = oldestStore.hostLifecycleGeneration(on: .ssh(host))
            let listTmuxSessions = listTmuxSessions
            Task { [weak self, weak oldestStore] in
                let tmuxSessionNames = await Task.detached(priority: .utility) { listTmuxSessions(host) }.value
                self?.handleAnswer(tmuxSessionNames, from: host, sourceStore: oldestStore, generation: generation)
            }
        }
        scheduleWakeUp()
    }

    private func handleAnswer(
        _ tmuxSessionNames: Set<String>?, from host: String, sourceStore: ConversationStore?, generation: UInt64
    ) {
        hostsBeingAsked.remove(host)
        defer { scheduleWakeUp() }
        guard hasReconnectCandidate(on: host) else { stopTrying(host); return }
        guard let sourceStore, registry.stores.contains(where: { $0 === sourceStore }),
              sourceStore.isCurrentHostLifecycle(generation, on: .ssh(host)) else { return }
        guard let tmuxSessionNames else {
            noteFailure(on: host)
            return
        }
        schedule.stopTrying(host)
        for store in registry.stores {
            store.setTmuxSessionNames(tmuxSessionNames, on: .ssh(host))
            for tab in store.terminalSessions where tab.host == .ssh(host) && tab.isWaitingToReconnect {
                tab.isWaitingToReconnect = false
                guard tab.hasDroppedConnectionToTmux,
                      let tmuxSessionName = tab.tmuxSessionName,
                      tmuxSessionNames.contains(tmuxSessionName) else {
                    tabsWhoseCLIEnded.insert(tab.id)
                    continue
                }
                if let replacementID = store.reconnectRemoteTerminal(tab.id) {
                    reconnectedAtByTab[replacementID] = currentDate()
                }
            }
        }
    }

    private func noteFailure(on host: String) {
        guard hasReconnectCandidate(on: host) else { stopTrying(host); return }
        if !schedule.noteFailure(on: host, now: currentDate()) { stopTrying(host) }
    }

    private func hasReconnectCandidate(on host: String) -> Bool {
        registry.stores.contains { store in
            store.remoteHostList.hosts.contains(host) && !store.isDisconnected(host) && !store.isTearingDownWorkspace
                && store.terminalSessions.contains { $0.host == .ssh(host) && $0.isWaitingToReconnect && $0.hasDroppedConnectionToTmux }
        }
    }

    private func pruneHostsWithoutCandidates() {
        for host in schedule.hostsBeingTried where !hasReconnectCandidate(on: host) { stopTrying(host) }
    }

    private func stopTrying(_ host: String) {
        schedule.stopTrying(host)
        for tab in registry.stores.flatMap(\.terminalSessions) where tab.host == .ssh(host) {
            tab.isWaitingToReconnect = false
        }
    }

    private func scheduleWakeUp() {
        wakeUp?.cancel()
        guard wakesItselfUp, let nextTryAt = schedule.nextTryAt(excluding: hostsBeingAsked) else {
            wakeUp = nil
            return
        }
        let delay = max(nextTryAt.timeIntervalSince(currentDate()), 0)
        wakeUp = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.askDueHosts()
        }
    }
}
