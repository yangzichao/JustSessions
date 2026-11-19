import Foundation

struct RemoteHostCheck: Sendable {
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
        let shellStartupResult: RemoteShellStartupCheckResult?
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
                    id: .script,
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
