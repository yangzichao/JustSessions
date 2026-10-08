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

    @Test func withNothingLeftItSaysWhetherSearchOrTheRecentFilterHidItAll() {
        for refreshStatus in [HostRefreshStatus.refreshed(.now), nil] {
            #expect(message(refreshStatus, isSearching: true).text == "No matching projects or sessions")
            #expect(message(refreshStatus, recencyFilter: .recent).text == "No sessions in the past seven days")
            #expect(message(refreshStatus).text == "No sessions")
            #expect(!message(refreshStatus).isFailure)
        }
    }

    @Test func withNothingWaitingItNamesTheCLIsThatTellOrSaysAnSSHHostCannot() {
        #expect(message(nil, waitingFilter: .waitingForYou).text == "No Claude Code or Codex session is waiting for you")
        #expect(message(nil, on: .ssh("devbox"), waitingFilter: .waitingForYou).text == "SSH hosts don't tell when a session waits for you")
        #expect(message(nil, isSearching: true, waitingFilter: .waitingForYou).text == "No matching projects or sessions")
    }

    private func message(
        _ refreshStatus: HostRefreshStatus?,
        on host: SessionHost = .thisMac,
        isSearching: Bool = false,
        recencyFilter: SessionRecencyFilter = .all,
        waitingFilter: SessionWaitingFilter = .all
    ) -> SidebarEmptyHostMessage {
        SidebarEmptyHostMessage(
            host: host,
            refreshStatus: refreshStatus,
            isSearching: isSearching,
            recencyFilter: recencyFilter,
            waitingFilter: waitingFilter
        )
    }
}
