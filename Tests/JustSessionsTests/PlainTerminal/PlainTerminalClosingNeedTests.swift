import Testing

@testable import JustSessions

@MainActor
struct PlainTerminalClosingNeedTests {
    @Test func aWaitingSSHPlainTerminalInTmuxAsksAsItsShellMayStillRun() {
        let tab = makePlainTerminal(host: .ssh("devbox"), tmuxSessionName: "justsessions-terminal-a1b2c3d4", startsOnceShown: true)

        #expect(tab.closingNeed == .plainTerminal)
        #expect(!tab.closingStopsNothing)
    }

    @Test(arguments: [
        (SessionHost.thisMac, String?.some("justsessions-terminal-a1b2c3d4")),
        (SessionHost.ssh("devbox"), String?.none),
    ])
    func anotherWaitingPlainTerminalStartedNothing(host: SessionHost, tmuxSessionName: String?) {
        let tab = makePlainTerminal(host: host, tmuxSessionName: tmuxSessionName, startsOnceShown: true)

        #expect(tab.closingNeed == .nothingStarted)
    }

    @Test func anSSHPlainTerminalWhoseConnectionDroppedAsks() {
        let tab = makePlainTerminal(host: .ssh("devbox"), tmuxSessionName: "justsessions-terminal-a1b2c3d4")

        tab.processFinished(exitCode: RemoteHostCommandRunner.connectionFailureExitStatus)

        #expect(tab.hasDroppedConnectionToTmux)
        #expect(tab.closingNeed == .plainTerminal)
        #expect(!tab.closingStopsNothing)
        #expect(!tab.canKeepCLIRunningAfterClose)
    }

    @Test func anSSHPlainTerminalWhoseShellEndedStopsNothing() {
        let tab = makePlainTerminal(host: .ssh("devbox"), tmuxSessionName: "justsessions-terminal-a1b2c3d4")

        tab.processFinished(exitCode: 0)

        #expect(tab.closingNeed == .alreadyEnded)
    }

    private func makePlainTerminal(host: SessionHost, tmuxSessionName: String?, startsOnceShown: Bool = false) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil, provider: nil, projectPath: "/srv/app", action: nil, displayTitle: "Terminal · app",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host,
            tmuxSessionName: tmuxSessionName,
            startsOnceShown: startsOnceShown
        )
    }
}
