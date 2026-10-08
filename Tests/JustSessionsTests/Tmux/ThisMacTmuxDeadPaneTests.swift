import Testing
@testable import JustSessions

/// tmux tells a tab its failed CLI's status through the tab's title; see `ThisMacTmuxDeadPane`.
@MainActor
struct ThisMacTmuxDeadPaneTests {
    @Test func theTitleOfADeadPaneNamesItsStatus() throws {
        #expect(try #require(ThisMacTmuxDeadPane(terminalTitle: "justsessions-exited:2")).exitCode == 2)
        // A signal ended the CLI, and tmux has no status for it.
        #expect(try #require(ThisMacTmuxDeadPane(terminalTitle: "justsessions-exited:")).exitCode == nil)
        #expect(ThisMacTmuxDeadPane(terminalTitle: "01a10846-4c77-75e2-bec8-ab638...") == nil)
    }

    @Test func aTabInTmuxEndsWithItsCLIsStatusAndKeepsItWhenItsClientLetsGo() {
        let tab = makeTab(tmuxSessionName: "justsessions-claude-abc")

        tab.updateTerminalTitle("justsessions-exited:2")
        tab.processFinished(exitCode: 0)

        #expect(tab.hasExited)
        #expect(tab.exitCode == 2)
        #expect(tab.terminalTitle == nil)
    }

    @Test func outsideTmuxOnThisMacTheTitleIsOnlyATitle() {
        for tab in [makeTab(tmuxSessionName: nil), makeTab(tmuxSessionName: "justsessions-claude-abc", host: .ssh("devbox"))] {
            tab.updateTerminalTitle("justsessions-exited:2")

            #expect(!tab.hasExited)
            #expect(tab.terminalTitle == "justsessions-exited:2")
        }
    }

    private func makeTab(tmuxSessionName: String?, host: SessionHost = .thisMac) -> TerminalSession {
        TerminalSession(
            conversation: nil,
            provider: .claude,
            projectPath: "/tmp",
            action: .resume,
            displayTitle: "Paper",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host,
            tmuxSessionName: tmuxSessionName
        )
    }
}

/// SwiftTerm reports a tab's process ending with its raw wait status.
struct ProcessWaitStatusTests {
    @Test func aWaitStatusGivesTheStatusAProcessExitedWith() {
        #expect(ProcessWaitStatus.exitCode(fromWaitStatus: 0) == 0)
        #expect(ProcessWaitStatus.exitCode(fromWaitStatus: 2 << 8) == 2)
        #expect(ProcessWaitStatus.exitCode(fromWaitStatus: 255 << 8) == 255)
        // Ended by SIGKILL, or by SIGSEGV with a core dump.
        #expect(ProcessWaitStatus.exitCode(fromWaitStatus: 9) == nil)
        #expect(ProcessWaitStatus.exitCode(fromWaitStatus: 11 | 0x80) == nil)
    }
}
