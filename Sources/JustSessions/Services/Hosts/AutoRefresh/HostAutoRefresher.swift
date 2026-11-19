import AppKit

@MainActor
final class HostAutoRefresher {
    static let shared = HostAutoRefresher(backgroundChecker: HostBackgroundChecker(), signIns: .shared)

    static let checkInterval: Duration = .seconds(15)

    private let registry: WorkspaceWindowRegistry
    private let isAnyWindowOnScreen: () -> Bool
    private let refreshSSHHost: (ConversationStore, String) -> RemoteHostRefreshStart
    private let backgroundChecker: HostBackgroundChecker?
    private let signIns: RemoteSignIns?
    private var schedule = HostAutoRefreshSchedule()
    private var checking: Task<Void, Never>?
    // periphery:ignore - held so the observation lasts as long as the refresher.
    private var activationObserver: (any NSObjectProtocol)?

    init(
        registry: WorkspaceWindowRegistry = .shared,
        isAnyWindowOnScreen: (() -> Bool)? = nil,
        refreshSSHHost: @escaping (ConversationStore, String) -> RemoteHostRefreshStart = { $0.refreshRemoteHost($1) },
        backgroundChecker: HostBackgroundChecker? = nil,
        signIns: RemoteSignIns? = nil
    ) {
        self.registry = registry
        self.isAnyWindowOnScreen = isAnyWindowOnScreen ?? { registry.hasWindowOnScreen }
        self.refreshSSHHost = refreshSSHHost
        self.backgroundChecker = backgroundChecker
        self.signIns = signIns
    }

    func start() {
        guard checking == nil else { return }
        // The app's windows may not count as on screen yet when it comes forward, so this doesn't wait for them.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDueHosts()
                self?.signIns?.appCameForward()
            }
        }
        checking = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.checkInterval)
                self?.check()
            }
        }
    }

    func check(now: Date = .now) {
        guard isAnyWindowOnScreen() else { return }
        refreshDueHosts(now: now)
    }

    func refreshDueHosts(now: Date = .now) {
        let stores = registry.stores
        guard let oldestStore = stores.first else { return }
        if schedule.isThisMacDue(
            lastRefreshStartedAt: oldestStore.lastRefreshStartedAt,
            status: oldestStore.hostRefreshStatuses[.thisMac],
            now: now
        ) {
            for store in stores where !store.isScanningThisMac { store.refreshThisMac() }
        }
        for host in oldestStore.remoteHostList.hosts
        where !oldestStore.isDisconnected(host)
            && schedule.isSSHHostDue(
                host,
                status: oldestStore.hostRefreshStatuses[.ssh(host)],
                needsLogIn: oldestStore.sshHostsNeedingLogIn.contains(host),
                now: now
            )
        {
            guard case .started(let refresh) = refreshSSHHost(oldestStore, host) else { continue }
            schedule.noteTry(on: host, at: now)
            Task { [weak self, weak oldestStore] in
                await refresh.value
                guard let self, let oldestStore else { return }
                self.schedule.noteResult(on: host, status: oldestStore.hostRefreshStatuses[.ssh(host)])
            }
        }
        backgroundChecker?.checkDueHost(in: stores, now: now)
        signIns?.lookAtHosts(
            oldestStore.remoteHostList.hosts.filter { !oldestStore.isDisconnected($0) },
            needingLogIn: oldestStore.sshHostsNeedingLogIn,
            now: now
        )
    }
}
