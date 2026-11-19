import Testing

@testable import JustSessions

/// A tab whose CLI or shell already ended closes without asking, since closing it stops nothing. An SSH tab in tmux
/// still asks: its connection ending doesn't mean its CLI did.
@MainActor
struct EndedTabClosingTests {
    @Test(arguments: [
        (ConversationProvider?.some(.claude), String?.some("justsessions-ended-tab-test")),
        (ConversationProvider?.some(.claude), String?.none),
        (ConversationProvider?.none, String?.none),
    ])
    func anEndedTabOnThisMacStopsNothingWhenClosed(provider: ConversationProvider?, tmuxSessionName: String?) {
        let tab = makeTab(provider: provider, host: .thisMac, tmuxSessionName: tmuxSessionName)
        #expect(!tab.closingStopsNothing)

        tab.processFinished(exitCode: 0)

        #expect(tab.closingStopsNothing)
    }

    @Test func anEndedSSHTabWithoutTmuxStopsNothingWhenClosed() {
        let tab = makeTab(provider: .claude, host: .ssh("devbox"), tmuxSessionName: nil)

        tab.processFinished(exitCode: 255)

        #expect(tab.closingStopsNothing)
    }

    @Test func anEndedSSHTabInTmuxStillAsks() {
        let tab = makeTab(provider: .claude, host: .ssh("devbox"), tmuxSessionName: "justsessions-ended-tab-test")

        tab.processFinished(exitCode: 255)

        #expect(!tab.closingStopsNothing)
        #expect(tab.canKeepCLIRunningAfterClose)
    }

    private func makeTab(provider: ConversationProvider?, host: SessionHost, tmuxSessionName: String?) -> TerminalSession {
        TerminalSession(
            engine: .swiftTerm,
            conversation: nil, provider: provider, projectPath: "/tmp", action: nil, displayTitle: "Tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host,
            tmuxSessionName: tmuxSessionName
        )
    }
}
