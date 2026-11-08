import Testing
@testable import JustSessions

@MainActor
struct PlainTerminalFinderTests {
    /// The shell runs in tmux, which the terminal shows on its alternate screen.
    @Test func searchesTmuxsHistoryWhileTheTerminalShowsTmux() async throws {
        let terminal = TerminalFinderStandIn()
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(5)])
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: tmux.history) { true }
        var reports: [TerminalFindMatchCount?] = []
        finder.onMatchCount = { reports.append($0) }

        #expect(finder.findText("needle") == nil)

        try await expectEventually { reports.count == 1 }
        #expect(reports == [TerminalFindMatchCount(total: 5, selectedNumber: 1, exceedsCountLimit: false)])
        #expect(terminal.calls.isEmpty)
    }

    /// As on an SSH host without tmux, where the shell runs right in the terminal.
    @Test func searchesTheTerminalsScrollbackOtherwise() {
        let terminal = TerminalFinderStandIn()
        let tmux = ScriptedTmuxHistory(countOutputs: [])
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: tmux.history) { false }
        var reports: [TerminalFindMatchCount?] = []
        finder.onMatchCount = { reports.append($0) }

        _ = finder.findText("needle")
        _ = finder.findTextAgain("needle", direction: .towardOlder)
        finder.endTextFind()

        #expect(terminal.calls == [.find("needle"), .findAgain("needle", .towardOlder), .end])
        #expect(reports == [terminal.matchCount, terminal.matchCount])
        #expect(tmux.commands.isEmpty)
    }

    /// A program on the alternate screen, such as vim, would otherwise move a search between finders as it starts
    /// or quits.
    @Test func aSearchKeepsItsFinderUntilItEnds() async throws {
        let terminal = TerminalFinderStandIn()
        let tmux = ScriptedTmuxHistory(countOutputs: [ScriptedTmuxHistory.countLine(2)])
        var showsTmux = false
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: tmux.history) { showsTmux }

        _ = finder.findText("needle")
        showsTmux = true
        _ = finder.findText("needles")
        #expect(terminal.calls == [.find("needle"), .find("needles")])

        finder.endTextFind()
        _ = finder.findText("needle")
        try await expectEventually { tmux.commands.count == 1 }
        #expect(terminal.calls.last == .end)
    }

    /// As on an SSH host whose tmux went away since the tab opened.
    @Test func aSearchTmuxCouldNotRunGoesOnInTheTerminal() async throws {
        let terminal = TerminalFinderStandIn()
        let tmux = ScriptedTmuxHistory(countOutputs: [nil])
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: tmux.history) { true }
        var reports: [TerminalFindMatchCount?] = []
        finder.onMatchCount = { reports.append($0) }

        _ = finder.findText("needle")

        try await expectEventually { reports.count == 1 }
        #expect(reports == [terminal.matchCount])
        #expect(terminal.calls == [.find("needle")])
        _ = finder.findTextAgain("needle", direction: .towardNewer)
        #expect(terminal.calls.last == .findAgain("needle", .towardNewer))
    }

    /// As in tmux 3.4, which counts nothing: the search goes on in tmux, with no count.
    @Test func aSearchTmuxFoundButDidntCountStaysInTmux() async throws {
        let terminal = TerminalFinderStandIn()
        let tmux = ScriptedTmuxHistory(countOutputs: Array(repeating: ScriptedTmuxHistory.countLine(nil, foundAny: true), count: 2))
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: tmux.history) { true }
        var reports: [TerminalFindMatchCount?] = []
        finder.onMatchCount = { reports.append($0) }

        _ = finder.findText("needle")
        try await expectEventually { reports.count == 1 }
        _ = finder.findTextAgain("needle", direction: .towardOlder)

        try await expectEventually { reports.count == 2 }
        #expect(reports == [nil, nil])
        #expect(tmux.commands.count == 2)
        #expect(terminal.calls.isEmpty)
    }

    @Test func anEmptyQueryEndsTheSearchAndClearsTheCount() {
        let terminal = TerminalFinderStandIn()
        let finder = PlainTerminalFinder(terminalFinder: terminal, tmuxHistory: ScriptedTmuxHistory(countOutputs: []).history) { false }
        var reports: [TerminalFindMatchCount?] = []
        finder.onMatchCount = { reports.append($0) }

        _ = finder.findText("needle")
        _ = finder.findText("")

        #expect(terminal.calls == [.find("needle"), .end])
        #expect(reports == [terminal.matchCount, nil])
    }
}

/// The tab terminal's own find, which counts at once.
@MainActor
final class TerminalFinderStandIn: TerminalTextFinding {
    enum Call: Equatable {
        case find(String)
        case findAgain(String, TerminalFindDirection)
        case end
    }

    var calls: [Call] = []
    let matchCount = TerminalFindMatchCount(total: 7, selectedNumber: 1, exceedsCountLimit: false)

    func findText(_ query: String) -> TerminalFindMatchCount? {
        calls.append(.find(query))
        return matchCount
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) -> TerminalFindMatchCount? {
        calls.append(.findAgain(query, direction))
        return matchCount
    }

    func endTextFind() {
        calls.append(.end)
    }
}
