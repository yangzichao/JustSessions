import Testing

@testable import JustSessions

/// An ended remote tab leads to Check host when its host's heading warns of a problem or its CLI failed right after
/// starting; otherwise Check host stays a quiet button beside Reconnect.
@MainActor
struct TerminalEndedBarTests {
    @Test func aTabThatFailedRightAfterStartingLeadsToCheckHost() {
        #expect(bar(endedWithErrorSoonAfterStarting: true, hostProblem: nil).leadsToCheckHost)
    }

    @Test func aTabWhoseHostHasAProblemLeadsToCheckHost() {
        #expect(bar(endedWithErrorSoonAfterStarting: false, hostProblem: "tmux: server version is too old").leadsToCheckHost)
    }

    @Test func aTabThatEndedOtherwiseKeepsCheckHostQuiet() {
        #expect(!bar(endedWithErrorSoonAfterStarting: false, hostProblem: nil).leadsToCheckHost)
    }

    @Test func aTabOnThisMacHasNoCheckHostToLeadTo() {
        let bar = TerminalEndedBar(
            exitCode: 1,
            isWaitingToReconnect: false,
            endedWithErrorSoonAfterStarting: true,
            hostProblem: nil,
            onCheckHost: nil,
            onReconnect: nil
        )
        #expect(!bar.leadsToCheckHost)
    }

    private func bar(endedWithErrorSoonAfterStarting: Bool, hostProblem: String?) -> TerminalEndedBar {
        TerminalEndedBar(
            exitCode: 1,
            isWaitingToReconnect: false,
            endedWithErrorSoonAfterStarting: endedWithErrorSoonAfterStarting,
            hostProblem: hostProblem,
            onCheckHost: {},
            onReconnect: {}
        )
    }
}
