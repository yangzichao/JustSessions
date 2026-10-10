import Foundation
import Testing
@testable import JustSessions

struct SidebarEmptyHostMessageTests {
    @Test func aFailedRefreshShowsItsErrorEvenWhileSearching() {
        let failure = message(.failed("Could not connect to devbox."), on: .ssh("devbox"), isSearching: true)

        #expect(failure.text == "Could not connect to devbox.")
        #expect(failure.isFailure)
    }

    @Test func aRunningRefreshSaysWhatItDoesOnTheHost() {
        #expect(message(.refreshing, on: .thisMac).text == "Scanning sessions…")
        #expect(message(.refreshing, on: .ssh("devbox")).text == "Copying sessions…")
        #expect(!message(.refreshing, on: .thisMac, isSearching: true).isFailure)
    }

    @Test func anSSHHostsCopySaysWhichToolItIsOnAndHowFarItIs() {
        let step = RemoteSessionCopyStep(provider: .codex, number: 2, count: 6)

        #expect(message(.refreshing, on: .ssh("devbox"), copyStep: step).text == "Copying Codex sessions (2 of 6)…")
        #expect(message(.failed("Could not connect to devbox."), on: .ssh("devbox"), copyStep: step).text == "Could not connect to devbox.")
    }

    @Test func withNothingLeftItSaysWhetherSearchOrTheRecentFilterHidItAll() {
        for refreshStatus in [HostRefreshStatus.refreshed(.now), nil] {
            #expect(message(refreshStatus, isSearching: true).text == "No matching projects or sessions")
            #expect(message(refreshStatus, recencyFilter: .recent).text == "No sessions in the past seven days")
            #expect(message(refreshStatus).text == "No sessions")
            #expect(!message(refreshStatus).isFailure)
        }
    }

    @Test func withNothingRunningItSaysSoAndThatAnSSHHostIsKnownAsOfItsLastRefresh() {
        #expect(message(nil, statusFilter: .running).text == "No session is running")
        #expect(message(nil, on: .ssh("devbox"), statusFilter: .running).text == "No session was running at the last refresh")
        #expect(message(nil, isSearching: true, statusFilter: .running).text == "No matching projects or sessions")
    }

    @Test func withNothingWaitingItNamesTheCLIsThatTellOrSaysAnSSHHostCannot() {
        #expect(message(nil, statusFilter: .waitingForYou).text == "No Claude Code, Codex, Pi, or OpenCode session is waiting for you")
        #expect(message(nil, on: .ssh("devbox"), statusFilter: .waitingForYou).text == "SSH hosts don't tell when a session waits for you")
        #expect(message(nil, isSearching: true, statusFilter: .waitingForYou).text == "No matching projects or sessions")
    }

    private func message(
        _ refreshStatus: HostRefreshStatus?,
        on host: SessionHost = .thisMac,
        copyStep: RemoteSessionCopyStep? = nil,
        isSearching: Bool = false,
        recencyFilter: SessionRecencyFilter = .all,
        statusFilter: SessionStatusFilter = .all
    ) -> SidebarEmptyHostMessage {
        SidebarEmptyHostMessage(
            host: host,
            refreshStatus: refreshStatus,
            copyStep: copyStep,
            isSearching: isSearching,
            recencyFilter: recencyFilter,
            statusFilter: statusFilter
        )
    }
}
