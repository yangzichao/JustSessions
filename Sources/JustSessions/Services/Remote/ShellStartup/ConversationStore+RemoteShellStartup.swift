import Foundation

/// SSH hosts whose shell startup gets in the way of the app's commands; see `RemoteShellStartupCheck`. A host is checked
/// the first time it refreshes without a result: right after it is added, or, for a host added before the check
/// existed, on its next refresh. A refresh whose status probe says nothing about the host's CLIs, as such a startup
/// causes, checks it again, once a run, unless the last check found nothing the app can do; you check that host again
/// from its ⋯ menu after changing its startup files.
extension ConversationStore {
    /// Gives `RemoteHostShellStartups` each listed host's startup, as its last check found.
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

    /// After a refresh reached the host. `statusListedCLIs` is whether its status probe said which CLIs it has.
    func checkRemoteShellStartupIfNeeded(
        on host: String,
        statusListedCLIs: Bool,
        check: RemoteShellStartupCheck = RemoteShellStartupCheck()
    ) {
        // Another window may have checked the host since this one loaded the results.
        guard let result = RemoteShellStartupChecks.load(from: userDefaults).result(for: host) else {
            checkRemoteShellStartup(on: host, check: check)
            return
        }
        guard !statusListedCLIs, result.outcome != .blocked, hostsRecheckedShellStartup.insert(host).inserted else { return }
        checkRemoteShellStartup(on: host, check: check)
    }

    /// From the host's ⋯ menu, after you changed its startup files.
    func checkRemoteShellStartupAgain(on host: String, check: RemoteShellStartupCheck = RemoteShellStartupCheck()) {
        checkRemoteShellStartup(on: host, check: check)
    }

    /// When the host is removed.
    func forgetRemoteShellStartup(on host: String) {
        saveRemoteShellStartupCheck(nil, on: host)
        RemoteHostShellStartups.shared.setStartup(.interactive, on: host)
        hostsRecheckedShellStartup.remove(host)
    }

    private func checkRemoteShellStartup(on host: String, check: RemoteShellStartupCheck) {
        guard remoteHostList.hosts.contains(host), RemoteHostShellStartups.shared.beginCheck(on: host) else { return }
        hostsCheckingShellStartup.insert(host)
        Task.detached(priority: .utility) {
            let result = check.check(host: host)
            await self.finishRemoteShellStartupCheck(result, on: host)
        }
    }

    private func finishRemoteShellStartupCheck(_ result: RemoteShellStartupCheckResult?, on host: String) {
        RemoteHostShellStartups.shared.endCheck(on: host)
        hostsCheckingShellStartup.remove(host)
        guard let result, remoteHostList.hosts.contains(host) else { return }
        let previousStartup = RemoteHostShellStartups.shared.startup(on: host)
        saveRemoteShellStartupCheck(result, on: host)
        RemoteHostShellStartups.shared.setStartup(result.shellStartup, on: host)
        guard result.shellStartup != previousStartup else { return }
        for store in windowRegistry.stores {
            store.remakeTabsWaitingToBeShown(on: .ssh(host))
        }
        // The status probe lists the CLIs the host's shell finds as it now starts.
        refreshRemoteHost(host)
    }

    /// Saves over what is saved, which another window may have changed, and shows the result in every window.
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
