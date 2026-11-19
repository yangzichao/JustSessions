import Foundation

/// Runs the host checks `HostBackgroundCheckSchedule` says are due, for `HostAutoRefresher`, so they run only while a
/// workspace window shows on screen. One host is checked at a time, through the oldest window, and only a host whose
/// last refresh worked: one that can't be reached or needs Connect… already shows why on its heading, and one you
/// disconnected from is left alone. The host's
/// shell startup must have been checked already, by its refresh, which a background check takes over rather than
/// running it again; see `RemoteHostCheck`. A host whose check a window shows while it runs is left to that check.
@MainActor
final class HostBackgroundChecker {
    /// Starts a check of the host through the window's store, as `checkHostInBackground(_:)` does; tests fake it.
    private let checkHost: (ConversationStore, String) -> Task<Void, Never>?
    private let appVersion: () -> String
    private var runningCheck: (host: String, task: Task<Void, Never>)?

    init(
        appVersion: @escaping () -> String = { FeedbackEnvironment.current.appVersion },
        checkHost: @escaping (ConversationStore, String) -> Task<Void, Never>? = { $0.checkHostInBackground($1) }
    ) {
        self.appVersion = appVersion
        self.checkHost = checkHost
    }

    /// The host being checked now, if any.
    var hostBeingChecked: String? { runningCheck?.host }

    func checkDueHost(in stores: [ConversationStore], now: Date = .now) {
        guard runningCheck == nil, let oldestStore = stores.first else { return }
        let appVersion = appVersion()
        for host in oldestStore.remoteHostList.hosts {
            guard case .refreshed(let refreshedAt)? = oldestStore.hostRefreshStatuses[.ssh(host)],
                !oldestStore.sshHostsNeedingLogIn.contains(host), !oldestStore.isDisconnected(host),
                oldestStore.shellStartupCheck(on: host) != nil,
                !oldestStore.hostsCheckingShellStartup.contains(host),
                !stores.contains(where: { $0.isShowingRunningHostCheck(of: host) })
            else { continue }
            let tabAskedForCheck = stores.contains { $0.hostsAskingForBackgroundCheck.contains(host) }
            guard
                HostBackgroundCheckSchedule.reason(
                    keptCheck: oldestStore.keptHostChecks.check(for: host),
                    appVersion: appVersion,
                    lastRefresh: .init(refreshedAt: refreshedAt, tmuxServerProblem: oldestStore.tmuxServerProblemsByHost[host]),
                    tabAskedForCheck: tabAskedForCheck,
                    now: now
                ) != nil
            else { continue }
            guard let task = checkHost(oldestStore, host) else { continue }
            for store in stores { store.hostsAskingForBackgroundCheck.remove(host) }
            runningCheck = (host, task)
            Task { [weak self] in
                await task.value
                self?.runningCheck = nil
            }
            return
        }
    }
}
