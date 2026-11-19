import Foundation

extension ConversationStore {
    func applyRemoteShellStartups() {
        for host in remoteHostList.hosts {
            RemoteHostShellStartups.shared.setStartup(
                remoteShellStartupChecks.result(for: host)?.shellStartup ?? .interactive,
                on: host
            )
        }
    }

    func shellStartupCheck(on host: String) -> RemoteShellStartupCheckResult? {
        remoteShellStartupChecks.result(for: host)
    }

    func checkRemoteShellStartupIfNeeded(on host: String, statusListedCLIs: Bool) {
        let keptResult = RemoteShellStartupChecks.load(from: userDefaults).result(for: host)
        if keptResult == nil, statusListedCLIs {
            checkRemoteShellStartup(on: host)
        } else if !statusListedCLIs, keptResult?.outcome != .blocked {
            recheckRemoteShellStartupOncePerRun(on: host)
        }
    }

    private func recheckRemoteShellStartupOncePerRun(on host: String) {
        guard !hostsRecheckedShellStartup.contains(host) else { return }
        hostsRecheckedShellStartup.insert(host)
        checkRemoteShellStartup(on: host)
    }

    func forgetRemoteShellStartup(on host: String) {
        saveRemoteShellStartupCheck(nil, on: host)
        RemoteHostShellStartups.shared.setStartup(.interactive, on: host)
        hostsRecheckedShellStartup.remove(host)
    }

    private func checkRemoteShellStartup(on host: String) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), !isDisconnected(host),
            RemoteHostShellStartups.shared.beginCheck(on: host)
        else { return }
        hostsCheckingShellStartup.insert(host)
        let check = remoteShellStartupCheck
        let generation = hostLifecycleGeneration(on: .ssh(host))
        let task: Task<Void, Never> = Task.detached(priority: .utility) { [weak self] in
            let result = check.check(host: host)
            RemoteHostShellStartups.shared.endCheck(on: host)
            await self?.finishRemoteShellStartupCheck(result, on: host, generation: generation)
        }
        remoteHostWork.keepAuxiliary(task, on: host)
    }

    private func finishRemoteShellStartupCheck(_ result: RemoteShellStartupCheckResult?, on host: String, generation: UInt64) {
        guard hostLifecycleGeneration(on: .ssh(host)) == generation else { return }
        hostsCheckingShellStartup.remove(host)
        guard let result, isCurrentHostLifecycle(generation, on: .ssh(host)) else { return }
        applyRemoteShellStartupCheckResult(result, on: host)
    }

    func applyRemoteShellStartupCheckResult(_ result: RemoteShellStartupCheckResult, on host: String) {
        guard !isTearingDownWorkspace, remoteHostList.hosts.contains(host), !isDisconnected(host) else { return }
        let previousStartup = RemoteHostShellStartups.shared.startup(on: host)
        saveRemoteShellStartupCheck(result, on: host)
        RemoteHostShellStartups.shared.setStartup(result.shellStartup, on: host)
        guard result.shellStartup != previousStartup else { return }
        for store in windowRegistry.stores {
            store.remakeTabsWaitingToBeShown(on: .ssh(host))
        }
        refreshRemoteHost(host)
    }

    private func saveRemoteShellStartupCheck(_ result: RemoteShellStartupCheckResult?, on host: String) {
        var checks = RemoteShellStartupChecks.load(from: userDefaults)
        checks.setResult(result, for: host)
        checks.save(to: userDefaults)
        remoteShellStartupChecks = checks
        for store in windowRegistry.stores where store !== self {
            store.remoteShellStartupChecks = checks
        }
    }
}
