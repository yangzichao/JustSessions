import Foundation

/// Check this host…: logs in as the app's background commands do, checks the host's shell startup, looks up its CLIs
/// as a refresh does, then asks the host about everything else in one command; see `RemoteHostCheckScript`. A host
/// the app can't log in to is not asked anything more. Runs `ssh` several times, so call it off the main actor.
/// A check the app runs on its own takes the shell startup check's kept result instead of running it again, since
/// that check runs the host's interactive startup, which can leave what it starts, such as tmux, running there; see
/// `HostBackgroundChecker`. `startingStep` hears of each step as it starts, for the sheet to show.
struct RemoteHostCheck: Sendable {
    /// Room for every CLI's version within its own time limit.
    static let scriptTimeout: TimeInterval = 120

    let runner: RemoteHostCommandRunner
    let connectionCheck: RemoteHostConnectionCheck
    let shellStartupCheck: RemoteShellStartupCheck

    init(
        runner: RemoteHostCommandRunner = RemoteHostCommandRunner(),
        connectionCheck: RemoteHostConnectionCheck = RemoteHostConnectionCheck(),
        shellStartupCheck: RemoteShellStartupCheck = RemoteShellStartupCheck()
    ) {
        self.runner = runner
        self.connectionCheck = connectionCheck
        self.shellStartupCheck = shellStartupCheck
    }

    struct Outcome: Sendable {
        let report: HostCheckReport
        /// For the store to keep, as after Check shell startup; nil when it didn't run or didn't finish.
        let shellStartupResult: RemoteShellStartupCheckResult?
        /// For the store to keep, as after a refresh; nil when the lookup didn't answer.
        var cliLocations: [ConversationProvider: RemoteCLILocation]? = nil
    }

    func check(
        host: String,
        programs: [RemoteHostCheckProgram],
        session: HostCheckSession?,
        providersWithSessions: Set<ConversationProvider>,
        thisMacSummary: String,
        keptShellStartupResult: RemoteShellStartupCheckResult? = nil,
        checksShellStartup: Bool = true,
        now: () -> Date = Date.init,
        startingStep: (HostCheckStep) -> Void = { _ in }
    ) -> Outcome {
        var cliLocations: [ConversationProvider: RemoteCLILocation]?
        func outcome(_ findings: [HostCheckFinding], _ shellStartupResult: RemoteShellStartupCheckResult?) -> Outcome {
            Outcome(
                report: HostCheckReport(
                    host: host,
                    checkedAt: now(),
                    thisMacSummary: thisMacSummary,
                    findings: findings,
                    endedTabScreen: session?.endedTabScreen
                ),
                shellStartupResult: shellStartupResult,
                cliLocations: cliLocations
            )
        }

        startingStep(.logIn)
        let connectionProblem = connectionCheck.problem(connectingTo: host)
        var findings = [RemoteHostConnectionFindings.connectionFinding(problem: connectionProblem, host: host)]
        guard connectionProblem == nil else { return outcome(findings, nil) }

        if checksShellStartup { startingStep(.shellStartup) }
        let checkedShellStartup = checksShellStartup ? shellStartupCheck.check(host: host) : nil
        let shellStartupResult = checkedShellStartup ?? keptShellStartupResult
        let startup = shellStartupResult?.shellStartup ?? RemoteHostShellStartups.shared.startup(on: host)
        findings.append(RemoteHostConnectionFindings.shellStartupFinding(shellStartupResult, host: host, startup: startup))

        // Where tabs start each CLI from now, so the script checks that.
        startingStep(.cliLookup)
        cliLocations = RemoteHostStatusProbe.status(ofHost: host, startup: startup, runner: runner)?.cliLocations
        let programs = cliLocations.map { locations in programs.map { $0.located(by: locations) } } ?? programs
        let command = RemoteHostCheckScript.command(startup: startup, programs: programs, projectPath: session?.projectPath)
        startingStep(.hostCommand)
        guard let result = runner.run(host, command, Self.scriptTimeout),
            result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus
        else {
            findings.append(
                HostCheckFinding(
                    id: "script",
                    status: .problem,
                    title: AppLocalization.string("Host check"),
                    summary: AppLocalization.string(
                        "\(host) didn't answer the rest of the check within \(Int(Self.scriptTimeout)) seconds, or the connection dropped."
                    )
                ))
            return outcome(findings, checkedShellStartup)
        }
        let context = RemoteHostCheckContext(
            host: host,
            shellStartup: startup,
            programs: programs,
            session: session,
            providersWithSessions: providersWithSessions
        )
        findings += RemoteHostCheckFindings.findings(in: RemoteHostCheckOutput(result.output), context: context)
        return outcome(findings, checkedShellStartup)
    }
}
