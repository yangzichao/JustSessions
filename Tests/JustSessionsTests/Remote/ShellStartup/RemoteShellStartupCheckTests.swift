import Foundation
import Testing
@testable import JustSessions

/// How the check reads what the host printed. The outputs are shaped like those of max2, a Fedora 43 host, whose
/// `.bashrc.d` started tmux or zsh for every interactive shell.
struct RemoteShellStartupCheckTests {
    private static let tmuxTakeover = """
        ++JUSTSESSIONS /home/jr/.bashrc:20: '[' -f /home/jr/.bashrc.d/takeover.sh ']'\r
        ++JUSTSESSIONS /home/jr/.bashrc:21: . /home/jr/.bashrc.d/takeover.sh\r
        +++JUSTSESSIONS /home/jr/.bashrc.d/takeover.sh:2: '[' -z '' ']'\r
        +++JUSTSESSIONS /home/jr/.bashrc.d/takeover.sh:3: exec tmux\r
        \u{1B}[?1049h\u{1B}[H\u{1B}[2Jjr@max2:~$ \u{1B}[30m\u{1B}[42m[0] 0:bash*\u{1B}(B\u{1B}[m
        """

    @Test func aStartupThatLetsTheCommandRunNeedsOneRun() {
        let runs = RecordedRuns([(0, "+JUSTSESSIONS /bin/bash:1: printf '%s%s\\n' __JUSTSESSIONS_SHELL_ STARTUP_OK__\r\n__JUSTSESSIONS_SHELL_STARTUP_OK__\r\nConnection to max2 closed.\r\n")])
        let result = RemoteShellStartupCheck(run: runs.run).check(host: "max2")

        #expect(result == RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil))
        #expect(runs.commands == [RemoteShellStartupCheck.tracedInteractiveCommand])
    }

    @Test func aStartupThatTakesOverUsesALoginShellWhenThatRunsTheCommand() {
        let runs = RecordedRuns([(nil, Self.tmuxTakeover), (0, "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n")])
        let result = RemoteShellStartupCheck(run: runs.run).check(host: "max2")

        #expect(result == RemoteShellStartupCheckResult(
            outcome: .usesLoginShellOnly,
            stoppedAt: "/home/jr/.bashrc.d/takeover.sh:3: exec tmux"
        ))
        #expect(runs.commands == [RemoteShellStartupCheck.tracedInteractiveCommand, RemoteShellStartupCheck.loginOnlyCommand])
    }

    @Test func aStartupThatTakesOverEvenALoginShellBlocksTheHost() {
        let zshTakeover = "+++JUSTSESSIONS /home/jr/.bashrc.d/takeover.sh:3: exec /usr/bin/zsh -l\r\n\u{1B}[1m\u{1B}[7m%\u{1B}[27m\u{1B}[1m\u{1B}[0m zsh ~ % \u{1B}[K\u{1B}[?2004h"
        let runs = RecordedRuns([(nil, zshTakeover), (nil, "\u{1B}[1m%\u{1B}[0m zsh ~ % ")])

        #expect(RemoteShellStartupCheck(run: runs.run).check(host: "max2") == RemoteShellStartupCheckResult(
            outcome: .blocked,
            stoppedAt: "/home/jr/.bashrc.d/takeover.sh:3: exec /usr/bin/zsh -l"
        ))
    }

    @Test func aShellThatTracesNothingStillGetsAnOutcome() {
        let runs = RecordedRuns([(nil, "Welcome to fish\r\nme@host ~> "), (0, "__JUSTSESSIONS_SHELL_STARTUP_OK__\n")])
        #expect(RemoteShellStartupCheck(run: runs.run).check(host: "max2")
            == RemoteShellStartupCheckResult(outcome: .usesLoginShellOnly, stoppedAt: nil))
    }

    @Test func noOutcomeWhenTheHostCouldNotBeReachedOrSaidNothing() {
        #expect(RemoteShellStartupCheck(run: RecordedRuns([(255, "ssh: connect to host max2 port 22: Network is unreachable")]).run)
            .check(host: "max2") == nil)
        #expect(RemoteShellStartupCheck(run: RecordedRuns([(nil, " \r\n")]).run).check(host: "max2") == nil)
        #expect(RemoteShellStartupCheck(run: RecordedRuns([nil]).run).check(host: "max2") == nil)
        // The login shell's run is needed to tell what to do.
        #expect(RemoteShellStartupCheck(run: RecordedRuns([(nil, Self.tmuxTakeover), (255, "")]).run).check(host: "max2") == nil)
    }

    @Test func theCommandsNeverPrintTheMarkerWholeExceptByRunning() {
        for command in [RemoteShellStartupCheck.tracedInteractiveCommand, RemoteShellStartupCheck.loginOnlyCommand] {
            #expect(!command.contains(RemoteShellStartupCheck.marker))
        }
        // A trace or an echo of the marker command doesn't count; what the terminal printed before the marker doesn't
        // hide it.
        #expect(!RemoteShellStartupCheck.printedMarker("+JUSTSESSIONS zsh:1: printf '%s%s\\n' __JUSTSESSIONS_SHELL_ STARTUP_OK__"))
        #expect(RemoteShellStartupCheck.printedMarker("\u{1B}[0m__JUSTSESSIONS_SHELL_STARTUP_OK__\r"))
        #expect(RemoteShellStartupCheck.printedMarker("^D\u{08}\u{08}__JUSTSESSIONS_SHELL_STARTUP_OK__\r"))
    }

    @Test func whereTheStartupStoppedIsShortenedForATooltip() throws {
        let long = String(repeating: "x", count: 300)
        let stoppedAt = try #require(RemoteShellStartupCheck.lastTracedCommand(in: "+JUSTSESSIONS /home/jr/.zshrc:9: \(long)\n"))
        #expect(stoppedAt.count == 160)
        #expect(stoppedAt.hasPrefix("/home/jr/.zshrc:9: xxx") && stoppedAt.hasSuffix("…"))
        #expect(RemoteShellStartupCheck.lastTracedCommand(in: "no trace here") == nil)
    }
}

/// Answers each run with the next recorded result, and records the commands.
private final class RecordedRuns: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [(exitStatus: Int32?, output: String)?]
    private(set) var commands: [String] = []

    init(_ results: [(exitStatus: Int32?, output: String)?]) {
        self.results = results
    }

    var run: @Sendable (String, String, TimeInterval) -> (exitStatus: Int32?, output: String)? {
        { [self] _, command, _ in
            lock.withLock {
                commands.append(command)
                return results.isEmpty ? nil : results.removeFirst()
            }
        }
    }
}
