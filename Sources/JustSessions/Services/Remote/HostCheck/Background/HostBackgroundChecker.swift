import Foundation

@MainActor
final class HostBackgroundChecker {
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

    var hostBeingChecked: String? { runningCheck?.host }

    func checkDueHost(in stores: [ConversationStore], now: Date = .now) {
        guard runningCheck == nil, let oldestStore = stores.first else { return }
        let appVersion = appVersion()
        for host in oldestStore.remoteHostList.hosts {
            guard case .refreshed(let refreshedAt)? = oldestStore.hostRefreshStatuses[.ssh(host)],
                Self.isFreeToCheck(host, oldestStore: oldestStore, stores: stores)
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

    private static func isFreeToCheck(_ host: String, oldestStore: ConversationStore, stores: [ConversationStore]) -> Bool {
        !oldestStore.sshHostsNeedingLogIn.contains(host) && !oldestStore.isDisconnected(host)
            && oldestStore.shellStartupCheck(on: host) != nil
            && !oldestStore.hostsCheckingShellStartup.contains(host)
            && !stores.contains(where: { $0.isShowingRunningHostCheck(of: host) })
    }
}
