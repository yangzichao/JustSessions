import Foundation

/// Check this host…, from an SSH host's ⋯ menu or its refresh warning, and Check host on an SSH tab whose command
/// ended, which also checks that tab's folder and CLI and keeps what the tab showed. The window's sheet shows the
/// check while it runs, then its report; see `RemoteHostCheck`. The shell startup it finds is kept as the shell
/// startup check's own would be, and its report as the host's last check; see `ConversationStore+BackgroundHostCheck`.
extension ConversationStore {
    func checkHost(_ host: String, session: HostCheckSession? = nil) {
        connectIfDisconnected(.ssh(host))
        let state = HostCheckSheetState(host: host, session: session)
        hostCheck = state
        runHostCheck(state)
    }

    /// Check host on an SSH tab whose command ended, as when its session failed to resume.
    func checkHost(ofTerminal id: UUID) {
        guard let tab = terminalSessions.first(where: { $0.id == id }), let host = tab.host.sshDestination else { return }
        checkHost(
            host,
            session: HostCheckSession(
                provider: tab.provider,
                projectPath: tab.projectPath,
                endedTabScreen: tab.shownTextForHostCheck
            ))
    }

    /// From the warning on an SSH host's heading: the report of the host's last check, which the warning is about, or
    /// a new check when there is none, as when only the last refresh's tmux noticed a problem.
    func showHostCheck(_ host: String) {
        guard let keptCheck = keptHostChecks.check(for: host),
            tmuxServerProblemsByHost[host] == nil
                || keptCheck.report.findings.contains(where: { $0.id == "tmux" && $0.status == .problem })
        else {
            checkHost(host)
            return
        }
        hostCheck = HostCheckSheetState(host: host, session: nil, report: keptCheck.report)
    }

    /// Check again in the sheet, as after you changed something on the host.
    func checkShownHostAgain() {
        guard var state = hostCheck, !state.isChecking else { return }
        state.runID = UUID()
        state.report = nil
        state.step = .logIn
        state.stepStartedAt = .now
        hostCheck = state
        runHostCheck(state)
    }

    /// Logs in even when the host couldn't be reached a moment ago, since you asked.
    private func runHostCheck(_ state: HostCheckSheetState) {
        let host = state.host
        SSHHostReachability.shared.forget(host)
        let programs = RemoteHostCheckProgram.all { customStartCommand(for: $0, on: .ssh(host)) }
        let providersWithSessions = Set(conversations.filter { $0.host == .ssh(host) }.map(\.provider))
        let check = remoteHostCheck
        let session = state.session
        let runID = state.runID
        Task.detached(priority: .userInitiated) {
            let outcome = check.check(
                host: host,
                programs: programs,
                session: session,
                providersWithSessions: providersWithSessions,
                thisMacSummary: HostCheckThisMacSummary.current(),
                startingStep: { step in
                    Task { @MainActor in self.showHostCheckStep(step, runID: runID) }
                }
            )
            await self.finishHostCheck(outcome, host: host, runID: runID)
        }
    }

    private func showHostCheckStep(_ step: HostCheckStep, runID: UUID) {
        // A step can arrive after a later one, or after the report.
        guard let state = hostCheck, state.runID == runID, state.isChecking, step > state.step else { return }
        hostCheck?.step = step
        hostCheck?.stepStartedAt = .now
    }

    private func finishHostCheck(_ outcome: RemoteHostCheck.Outcome, host: String, runID: UUID) {
        applyHostCheckOutcome(outcome, host: host)
        // The sheet may have closed, or started another run, since.
        guard hostCheck?.runID == runID else { return }
        hostCheck?.report = outcome.report
    }

    /// Keeps what any check of the host found, whether asked for or run by the app on its own.
    func applyHostCheckOutcome(_ outcome: RemoteHostCheck.Outcome, host: String) {
        guard remoteHostList.hosts.contains(host) else { return }
        if let shellStartupResult = outcome.shellStartupResult {
            applyRemoteShellStartupCheckResult(shellStartupResult, on: host)
        }
        if let cliLocations = outcome.cliLocations {
            RemoteHostCLILocations.shared.setLocations(cliLocations, on: host)
            setInstalledProviders(Set(cliLocations.keys), on: .ssh(host))
        }
        keepHostCheck(KeptHostCheck(report: outcome.report, appVersion: FeedbackEnvironment.current.appVersion), on: host)
    }
}
