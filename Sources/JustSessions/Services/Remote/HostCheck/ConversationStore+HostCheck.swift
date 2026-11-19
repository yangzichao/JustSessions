import Foundation

extension ConversationStore {
    func checkHost(_ host: String, session: HostCheckSession? = nil) {
        connectIfDisconnected(.ssh(host))
        let state = HostCheckSheetState(host: host, session: session)
        hostCheck = state
        runHostCheck(state)
    }

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

    func showHostCheck(_ host: String) {
        guard let keptCheck = keptHostChecks.check(for: host),
            !keptReportMissesTmuxServerProblem(keptCheck.report, on: host)
        else {
            checkHost(host)
            return
        }
        hostCheck = HostCheckSheetState(host: host, session: nil, report: keptCheck.report)
    }

    private func keptReportMissesTmuxServerProblem(_ report: HostCheckReport, on host: String) -> Bool {
        tmuxServerProblemsByHost[host] != nil && !report.foundTmuxServerUnreachable
    }

    func checkShownHostAgain() {
        guard var state = hostCheck, !state.isChecking else { return }
        state.runID = UUID()
        state.report = nil
        state.step = .logIn
        state.stepStartedAt = .now
        hostCheck = state
        runHostCheck(state)
    }

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
        guard let state = hostCheck, state.runID == runID, state.isChecking, step > state.step else { return }
        hostCheck?.step = step
        hostCheck?.stepStartedAt = .now
    }

    private func finishHostCheck(_ outcome: RemoteHostCheck.Outcome, host: String, runID: UUID) {
        applyHostCheckOutcome(outcome, host: host)
        guard hostCheck?.runID == runID else { return }
        hostCheck?.report = outcome.report
    }

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
