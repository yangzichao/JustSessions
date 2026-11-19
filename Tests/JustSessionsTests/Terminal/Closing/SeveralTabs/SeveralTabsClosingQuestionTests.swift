import Testing

@testable import JustSessions

/// Close all tabs in group… asks once for every tab, and only what a single tab's close would ask.
struct SeveralTabsClosingQuestionTests {
    /// Every tab on hosts with the same saved choice.
    private func question(
        _ needs: [TabClosingNeed],
        tabCloseChoice: TabCloseChoice = .askEachTime,
        plainTerminalCloseChoice: PlainTerminalCloseChoice = .askEachTime
    ) -> SeveralTabsClosingQuestion {
        SeveralTabsClosingQuestion(
            tabs: needs.map { (need: $0, tabCloseChoice: tabCloseChoice) },
            plainTerminalCloseChoice: plainTerminalCloseChoice
        )
    }

    @Test func cliTmuxCanKeepRunningAskKeepRunningOrEndSessions() {
        #expect(question([.canKeepCLIRunning, .canKeepCLIRunning]) == .keepOrEndCLIs(alsoStopsOthers: false))
    }

    @Test func otherTabsStoppingEitherWayAreNamedInTheQuestion() {
        #expect(question([.canKeepCLIRunning, .plainTerminal]) == .keepOrEndCLIs(alsoStopsOthers: true))
        #expect(question([.canKeepCLIRunning, .cliStopsWithTab]) == .keepOrEndCLIs(alsoStopsOthers: true))
        // A plain terminal you chose to close without asking still stops, so the question still says so.
        #expect(
            question([.canKeepCLIRunning, .plainTerminal], plainTerminalCloseChoice: .closeWithoutAsking)
                == .keepOrEndCLIs(alsoStopsOthers: true))
    }

    @Test func aSavedChoiceClosesTmuxCLIsWithoutAsking() {
        #expect(
            question([.canKeepCLIRunning, .canKeepCLIRunning], tabCloseChoice: .keepRunning)
                == .closeWithoutAsking)
        #expect(
            question([.canKeepCLIRunning, .plainTerminal], tabCloseChoice: .endSession, plainTerminalCloseChoice: .closeWithoutAsking)
                == .closeWithoutAsking)
    }

    /// Tabs on hosts that each saved a choice close without asking, each as its host's choice says.
    @Test func tabsOnHostsWithDifferentSavedChoicesCloseWithoutAsking() {
        let tabs: [(need: TabClosingNeed, tabCloseChoice: TabCloseChoice)] = [
            (.canKeepCLIRunning, .keepRunning), (.canKeepCLIRunning, .endSession),
        ]
        #expect(SeveralTabsClosingQuestion(tabs: tabs, plainTerminalCloseChoice: .askEachTime) == .closeWithoutAsking)
    }

    /// One CLI in tmux on a host that asks each time makes the whole close ask; a host's choice matters only to a CLI
    /// tmux can keep running there.
    @Test func aCLIOnAHostThatAsksMakesTheCloseAsk() {
        let askingHostTabs: [(need: TabClosingNeed, tabCloseChoice: TabCloseChoice)] = [
            (.canKeepCLIRunning, .keepRunning), (.canKeepCLIRunning, .askEachTime),
        ]
        #expect(
            SeveralTabsClosingQuestion(tabs: askingHostTabs, plainTerminalCloseChoice: .askEachTime)
                == .keepOrEndCLIs(alsoStopsOthers: false))
        let startedNothingOnAskingHost: [(need: TabClosingNeed, tabCloseChoice: TabCloseChoice)] = [
            (.canKeepCLIRunning, .keepRunning), (.nothingStarted, .askEachTime),
        ]
        #expect(
            SeveralTabsClosingQuestion(tabs: startedNothingOnAskingHost, plainTerminalCloseChoice: .askEachTime)
                == .closeWithoutAsking)
    }

    /// The saved choice answers for the CLIs in tmux, but a tab whose CLI or shell stops still asks first.
    @Test func aSavedTmuxChoiceStillAsksWhenOtherTabsWouldStop() {
        #expect(question([.canKeepCLIRunning, .cliStopsWithTab], tabCloseChoice: .keepRunning) == .keepOrEndCLIs(alsoStopsOthers: true))
        #expect(question([.canKeepCLIRunning, .plainTerminal], tabCloseChoice: .keepRunning) == .keepOrEndCLIs(alsoStopsOthers: true))
    }

    @Test func tabsWhoseCLIsOrShellsStopAskWhetherToStopThem() {
        #expect(question([.plainTerminal, .cliStopsWithTab]) == .stopEverything)
        #expect(question([.cliStopsWithTab], plainTerminalCloseChoice: .closeWithoutAsking) == .stopEverything)
        #expect(
            question([.plainTerminal, .plainTerminal], plainTerminalCloseChoice: .closeWithoutAsking)
                == .closeWithoutAsking)
    }

    @Test func tabsThatStopNothingCloseWithoutAsking() {
        #expect(question([.nothingStarted, .alreadyEnded]) == .closeWithoutAsking)
    }

    @Test func eachTabsNeedFollowsTheOrderASingleTabsCloseChecks() {
        #expect(
            TabClosingNeed(isWaitingToBeShown: true, closingStopsNothing: true, canKeepCLIRunningAfterClose: true, isPlainTerminal: true)
                == .nothingStarted)
        #expect(
            TabClosingNeed(isWaitingToBeShown: false, closingStopsNothing: true, canKeepCLIRunningAfterClose: false, isPlainTerminal: true)
                == .alreadyEnded)
        #expect(
            TabClosingNeed(isWaitingToBeShown: false, closingStopsNothing: false, canKeepCLIRunningAfterClose: true, isPlainTerminal: true)
                == .canKeepCLIRunning)
        #expect(
            TabClosingNeed(isWaitingToBeShown: false, closingStopsNothing: false, canKeepCLIRunningAfterClose: false, isPlainTerminal: true)
                == .plainTerminal)
        #expect(
            TabClosingNeed(
                isWaitingToBeShown: false, closingStopsNothing: false, canKeepCLIRunningAfterClose: false, isPlainTerminal: false)
                == .cliStopsWithTab)
    }
}
