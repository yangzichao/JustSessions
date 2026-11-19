import Foundation

extension ConversationStore {
    @discardableResult
    func checkHostInBackground(_ host: String) -> Task<Void, Never>? {
        guard remoteHostList.hosts.contains(host) else { return nil }
        let programs = RemoteHostCheckProgram.all { customStartCommand(for: $0, on: .ssh(host)) }
        let providersWithSessions = Set(conversations.filter { $0.host == .ssh(host) }.map(\.provider))
        let keptShellStartupResult = shellStartupCheck(on: host)
        let check = remoteHostCheck
        return Task.detached(priority: .utility) {
            let outcome = check.check(
                host: host,
                programs: programs,
                session: nil,
                providersWithSessions: providersWithSessions,
                thisMacSummary: HostCheckThisMacSummary.current(),
                keptShellStartupResult: keptShellStartupResult,
                checksShellStartup: false
            )
            await self.applyHostCheckOutcome(outcome, host: host)
        }
    }

    func isShowingRunningHostCheck(of host: String) -> Bool {
        hostCheck?.host == host && hostCheck?.isChecking == true
    }

    func keepHostCheck(_ check: KeptHostCheck?, on host: String) {
        var checks = KeptHostChecks.load(from: userDefaults)
        checks.setCheck(check, for: host)
        checks.save(to: userDefaults)
        for store in windowRegistry.stores + [self] where store.keptHostChecks != checks {
            store.keptHostChecks = checks
        }
    }

    func setTmuxServerProblem(_ problem: String?, on host: String) {
        guard remoteHostList.hosts.contains(host), tmuxServerProblemsByHost[host] != problem else { return }
        tmuxServerProblemsByHost[host] = problem
    }

    func forgetHostChecks(on host: String) {
        keepHostCheck(nil, on: host)
        tmuxServerProblemsByHost.removeValue(forKey: host)
        hostsAskingForBackgroundCheck.remove(host)
    }

    func hostCheckProblemMessage(on host: String) -> String? {
        if let tmuxServerProblem = tmuxServerProblemsByHost[host] {
            return AppLocalization.string(
                "tmux on \(host) can't reach the tmux server running there, so its sessions can't be opened: \(tmuxServerProblem)"
            )
        }
        guard let firstProblem = keptHostChecks.check(for: host)?.report.hostProblems.first else { return nil }
        return "\(firstProblem.title): \(firstProblem.summary)"
    }

    func noteCLIEnded(in tab: TerminalSession) {
        guard let host = tab.host.sshDestination, !tab.isPlainTerminal, tab.endedWithErrorSoonAfterStarting else { return }
        hostsAskingForBackgroundCheck.insert(host)
    }
}
