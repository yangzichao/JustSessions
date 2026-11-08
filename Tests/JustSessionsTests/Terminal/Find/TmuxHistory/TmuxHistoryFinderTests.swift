import Testing
@testable import JustSessions

@MainActor
struct TmuxHistoryFinderTests {
    @Test func aSearchCountsInTmuxAndSelectsTheNewestMatch() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(3)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        #expect(finder.findText("needle") == nil)

        try await expectEventually { reports.count == 1 }
        #expect(reports == [TerminalFindMatchCount(total: 3, selectedNumber: 1, exceedsCountLimit: false)])
        #expect(tmux.commands == [TmuxHistorySearchCommands.startingSearch(for: "needle", inSession: tmux.sessionName)])
    }

    /// Matches are numbered from the newest, and both directions wrap around.
    @Test func movesNumberTheSelectedMatchAndWrapAround() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: Array(repeating: ScriptedTmuxHistory.countLine(3), count: 5))
        let finder = TmuxHistoryFinder(history: tmux.history)
        var selectedNumbers: [Int?] = []
        finder.onStepFinished = { selectedNumbers.append($0?.selectedNumber) }

        _ = finder.findText("needle")
        for direction in [TerminalFindDirection.towardOlder, .towardOlder, .towardOlder, .towardNewer] {
            _ = finder.findTextAgain("needle", direction: direction)
        }

        try await expectEventually { selectedNumbers.count == 5 }
        #expect(selectedNumbers == [1, 2, 3, 1, 3])
        #expect(tmux.commands.last == TmuxHistorySearchCommands.movingSearch(.towardNewer, for: "needle", inSession: tmux.sessionName))
    }

    /// As after a key pressed in copy mode, which takes tmux's count away.
    @Test func aMoveWithoutACountKeepsTheTotalBeforeIt() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(4), ScriptedTmuxHistory.countLine(nil)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("needle")
        _ = finder.findTextAgain("needle", direction: .towardOlder)

        try await expectEventually { reports.count == 2 }
        #expect(reports.last == TerminalFindMatchCount(total: 4, selectedNumber: 2, exceedsCountLimit: false))
    }

    /// As when the shell printed more matches since: tmux doesn't say which match it selected.
    @Test func aTotalThatChangedUnderAMoveSelectsNoNumber() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(4), ScriptedTmuxHistory.countLine(6)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("needle")
        _ = finder.findTextAgain("needle", direction: .towardOlder)

        try await expectEventually { reports.count == 2 }
        #expect(reports.last == TerminalFindMatchCount(total: 6, selectedNumber: nil, exceedsCountLimit: false))
    }

    @Test func aNewSearchWithoutACountFoundNothing() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(nil)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("absent")

        try await expectEventually { reports.count == 1 }
        #expect(reports == [TerminalFindMatchCount.none])
    }

    @Test func aCountTmuxStoppedShortOfSelectsNoNumber() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(1000, partial: true)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("e")

        try await expectEventually { reports.count == 1 }
        #expect(reports == [TerminalFindMatchCount(total: 1000, selectedNumber: nil, exceedsCountLimit: true)])
    }

    /// As on an SSH host without tmux, or with the session gone.
    @Test func aSearchTmuxCouldNotRunReportsNoCount() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [nil])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("needle")

        try await expectEventually { reports.count == 1 }
        #expect(reports == [nil])
    }

    /// Typing faster than a slow host answers runs the search being typed now, and skips the ones it replaced.
    @Test func aSearchTypedWhileTmuxWasBusySkipsTheSearchesItReplaced() async throws {
        let tmux = ScriptedTmuxHistory(
            countOutputs: [ScriptedTmuxHistory.countLine(9), ScriptedTmuxHistory.countLine(2)],
            holdsFirstCommand: true
        )
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("n")
        try await expectEventually { tmux.commands.count == 1 }
        _ = finder.findText("ne")
        _ = finder.findText("nee")
        tmux.releaseFirstCommand()

        try await expectEventually { reports.count == 1 }
        #expect(tmux.searchedTexts == ["n", "nee"])
        #expect(reports == [TerminalFindMatchCount(total: 2, selectedNumber: 1, exceedsCountLimit: false)])
    }

    @Test func endingLeavesCopyModeOnlyAfterASearchAndReportsNothing() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(1)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        finder.endTextFind()
        _ = finder.findText("needle")
        try await expectEventually { reports.count == 1 }
        finder.endTextFind()
        finder.endTextFind()

        try await expectEventually { tmux.commands.count == 2 }
        #expect(tmux.commands.last == TmuxHistorySearchCommands.endingSearch(inSession: tmux.sessionName))
        #expect(reports.count == 1)
    }

    /// A move before any search starts one.
    @Test func aMoveBeforeASearchStartsOne() async throws {
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(2)])
        let finder = TmuxHistoryFinder(history: tmux.history)
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findTextAgain("needle", direction: .towardOlder)

        try await expectEventually { reports.count == 1 }
        #expect(tmux.commands == [TmuxHistorySearchCommands.startingSearch(for: "needle", inSession: tmux.sessionName)])
    }

    @Test func numbersWrapAroundInBothDirections() {
        #expect(TmuxHistoryFinder.number(after: 1, moving: .towardOlder, of: 3) == 2)
        #expect(TmuxHistoryFinder.number(after: 3, moving: .towardOlder, of: 3) == 1)
        #expect(TmuxHistoryFinder.number(after: 2, moving: .towardNewer, of: 3) == 1)
        #expect(TmuxHistoryFinder.number(after: 1, moving: .towardNewer, of: 3) == 3)
        #expect(TmuxHistoryFinder.number(after: 1, moving: .towardOlder, of: 1) == 1)
    }
}
