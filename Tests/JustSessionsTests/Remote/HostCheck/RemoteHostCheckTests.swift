import Foundation
import Testing

@testable import JustSessions

/// The check's steps, with `ssh` stood in for: the login, the shell startup, then the script.
struct RemoteHostCheckTests {
    static let shellStartupWorks = "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n"

    @Test func aHostTheAppCannotLogInToIsAskedNothingMore() {
        let recorder = RemoteCommandRecorder()
        let check = RemoteHostCheck(
            runner: recorder.runner(answering: (0, "")),
            connectionCheck: RemoteHostConnectionCheck(
                runner: recorder.runner(
                    answering: (
                        RemoteHostCommandRunner.connectionFailureExitStatus,
                        "me@devbox: Permission denied (publickey)."
                    ))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in
                Issue.record("Checked the shell startup")
                return nil
            })
        )

        var steps: [HostCheckStep] = []
        let outcome = check.check(
            host: "devbox",
            programs: [],
            session: nil,
            providersWithSessions: [],
            thisMacSummary: "This Mac",
            startingStep: { steps.append($0) }
        )

        #expect(steps == [.logIn])
        #expect(outcome.report.findings.map(\.id) == [.connection])
        #expect(outcome.report.findings.first?.status == .problem)
        #expect(outcome.shellStartupResult == nil)
        #expect(recorder.commands.map(\.command) == [WindowsHostProbe.command])
    }

    @Test func runsTheScriptInTheStartupTheShellStartupCheckFound() throws {
        let recorder = RemoteCommandRecorder()
        let scriptOutput = hostCheckScriptOutput([
            "rsync-path": "/usr/bin/rsync",
            "shell": "/bin/bash",
            "tmux-path": "/usr/bin/tmux",
            "tmux-version": "tmux 3.4",
            "tmux-server": "3.4",
            "tmux-server-exit": "0",
            "done": "",
        ])
        let check = RemoteHostCheck(
            runner: recorder.runner(answering: (0, scriptOutput)),
            connectionCheck: RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "%OS% :OS\n"))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, command, _ in
                command == RemoteShellStartupCheck.tracedInteractiveCommand
                    ? (nil, "+JUSTSESSIONS /home/me/.bashrc:7: exec tmux\r\n")
                    : (0, Self.shellStartupWorks)
            })
        )

        let outcome = check.check(
            host: "devbox",
            programs: [],
            session: nil,
            providersWithSessions: [],
            thisMacSummary: "JustSessions 1.2.10 · macOS 26.0.1",
            now: { Date(timeIntervalSince1970: 0) }
        )

        #expect(outcome.shellStartupResult?.outcome == .usesLoginShellOnly)
        #expect(outcome.report.findings.map(\.id) == [.connection, .shellStartup, .system, .rsync, .tmux])
        #expect(outcome.report.findings[1].status == .warning)
        #expect(outcome.report.findings[1].hostOutput == "/home/me/.bashrc:7: exec tmux")
        #expect(outcome.report.thisMacSummary == "JustSessions 1.2.10 · macOS 26.0.1")
        let scriptCommand = try #require(recorder.commands.last?.command)
        #expect(scriptCommand.contains("\"$SHELL\" -lc "))
    }

    /// For the sheet, which shows the step that runs.
    @Test func tellsOfEachStepAsItStarts() {
        let recorder = RemoteCommandRecorder()
        var steps: [HostCheckStep] = []
        var commandCountByStep: [HostCheckStep: Int] = [:]
        let check = RemoteHostCheck(
            runner: recorder.runner(answering: (0, hostCheckScriptOutput(["shell": "/bin/bash", "done": ""]))),
            connectionCheck: RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "%OS% :OS\n"))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in (0, Self.shellStartupWorks) })
        )

        _ = check.check(
            host: "devbox",
            programs: [],
            session: nil,
            providersWithSessions: [],
            thisMacSummary: "This Mac",
            startingStep: { step in
                steps.append(step)
                commandCountByStep[step] = recorder.commands.count
            }
        )

        #expect(steps == [.logIn, .shellStartup, .cliLookup, .hostCommand])
        // Each step is told of before its command runs: the login's, the lookup's, then the script's.
        #expect(commandCountByStep == [.logIn: 0, .shellStartup: 1, .cliLookup: 1, .hostCommand: 2])
        #expect(recorder.commands.count == 3)
    }

    /// A check the app runs on its own takes the kept shell startup result, so it has no such step.
    @Test func aCheckThatTakesTheKeptShellStartupSkipsItsStep() {
        let recorder = RemoteCommandRecorder()
        var steps: [HostCheckStep] = []
        let check = RemoteHostCheck(
            runner: recorder.runner(answering: (0, hostCheckScriptOutput(["shell": "/bin/bash", "done": ""]))),
            connectionCheck: RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "%OS% :OS\n"))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in
                Issue.record("Checked the shell startup")
                return nil
            })
        )

        _ = check.check(
            host: "devbox",
            programs: [],
            session: nil,
            providersWithSessions: [],
            thisMacSummary: "This Mac",
            keptShellStartupResult: RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil),
            checksShellStartup: false,
            startingStep: { steps.append($0) }
        )

        #expect(steps == [.logIn, .cliLookup, .hostCommand])
    }

    @Test func aScriptThatDoesNotFinishIsAProblem() {
        let recorder = RemoteCommandRecorder()
        let check = RemoteHostCheck(
            runner: recorder.runner(answering: nil),
            connectionCheck: RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "%OS% :OS\n"))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in (0, Self.shellStartupWorks) })
        )

        let outcome = check.check(host: "devbox", programs: [], session: nil, providersWithSessions: [], thisMacSummary: "This Mac")

        #expect(outcome.report.findings.map(\.id) == [.connection, .shellStartup, .script])
        #expect(outcome.report.findings.map(\.status) == [.passed, .passed, .problem])
        #expect(outcome.shellStartupResult?.outcome == .interactiveStartupWorks)
    }

    /// The check looks up the CLIs as a refresh does, checks each where tabs start it, and hands the store what it found.
    @Test func checksEachCLIWhereTheLookupFoundIt() throws {
        let recorder = RemoteCommandRecorder()
        let installedClaude = "/home/me/.claude/local/claude"
        let lookupOutput = """
            \(RemoteHostStatusProbe.installedCLIsHeading)
            codex
            \(RemoteHostStatusProbe.installFoldersHeading)
            claude \(installedClaude)

            """
        let check = RemoteHostCheck(
            runner: recorder.runner(answeringEach: { command in
                command.contains(RemoteHostStatusProbe.installFoldersHeading)
                    ? (0, lookupOutput)
                    : (0, hostCheckScriptOutput(["shell": "/bin/bash", "cli-claude-path": installedClaude, "done": ""]))
            }),
            connectionCheck: RemoteHostConnectionCheck(runner: recorder.runner(answering: (0, "%OS% :OS\n"))),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in (0, Self.shellStartupWorks) })
        )

        let outcome = check.check(
            host: "devbox",
            programs: RemoteHostCheckProgram.all { _ in nil },
            session: nil,
            providersWithSessions: [],
            thisMacSummary: "This Mac"
        )

        #expect(outcome.cliLocations == [.codex: .loginShell, .claude: .installed(path: installedClaude)])
        let scriptCommand = try #require(recorder.commands.last?.command)
        #expect(scriptCommand.contains("program=\"\(installedClaude)\""))
        let claude = try #require(outcome.report.findings.first { $0.id == .cli(.claude) })
        #expect(claude.summary.contains(installedClaude))
    }
}
