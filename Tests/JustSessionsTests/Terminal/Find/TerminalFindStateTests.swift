import Testing
@testable import JustSessions

@MainActor
struct TerminalFindStateTests {
    @Test func typingSearchesOnlyWhileTheBarShows() {
        let finder = RecordingTerminalFinder()
        let findState = TerminalFindState(finder: finder)

        findState.query = "kept"
        #expect(finder.calls.isEmpty)

        findState.show()
        #expect(findState.isPresented)
        #expect(finder.calls == [.find("kept")])
        #expect(findState.matchCount == finder.matchCount)

        findState.query = "kept!"
        #expect(finder.calls.last == .find("kept!"))
    }

    @Test func movesGoToTheFinderInTheirDirection() {
        let finder = RecordingTerminalFinder()
        let findState = TerminalFindState(finder: finder)
        findState.show()
        findState.query = "needle"

        findState.move(.towardOlder)
        findState.move(.towardNewer)

        #expect(finder.calls.suffix(2) == [.findAgain("needle", .towardOlder), .findAgain("needle", .towardNewer)])
    }

    @Test func nothingMovesWithoutAQueryOrABar() {
        let finder = RecordingTerminalFinder()
        let findState = TerminalFindState(finder: finder)
        findState.query = "needle"
        findState.move(.towardOlder)
        findState.show()
        findState.query = ""
        finder.calls.removeAll()

        findState.move(.towardOlder)

        #expect(finder.calls.isEmpty)
    }

    /// Closing ends the engine's search, which takes its highlight away, and keeps the text for the next ⌘F.
    @Test func closingEndsTheSearchAndKeepsTheText() {
        let finder = RecordingTerminalFinder()
        let findState = TerminalFindState(finder: finder)
        findState.show()
        findState.query = "needle"
        findState.isFieldFocused = true

        findState.close()

        #expect(!findState.isPresented)
        #expect(!findState.isFieldFocused)
        #expect(findState.matchCount == nil)
        #expect(findState.closeRevision == 1)
        #expect(finder.calls.last == .end)

        findState.show()
        #expect(finder.calls.last == .find("needle"))
    }

    /// Ghostty counts on its own thread and reports later, as its count grows and its selection moves, and its last
    /// report can come after the bar closed.
    @Test func showsCountsReportedLaterOnlyWhileTheBarShows() {
        let finder = RecordingTerminalFinder()
        finder.reportsWhenCalled = false
        let findState = TerminalFindState(finder: finder)
        findState.show()
        findState.query = "needle"
        #expect(findState.matchCount == nil)

        let total = TerminalFindMatchCount(total: 3, selectedNumber: nil, exceedsCountLimit: false)
        finder.onFindMatchCountChange?(total)
        #expect(findState.matchCount == total)
        finder.onFindMatchCountChange?(finder.matchCount)
        #expect(findState.matchCount == finder.matchCount)

        findState.close()
        finder.onFindMatchCountChange?(total)
        #expect(findState.matchCount == nil)
    }

    /// ⌘F while the bar shows puts the keyboard back in its field without searching again.
    @Test func showingAgainOnlyFocusesTheField() {
        let finder = RecordingTerminalFinder()
        let findState = TerminalFindState(finder: finder)
        findState.show()
        findState.query = "needle"
        let callCount = finder.calls.count
        let focusRevision = findState.focusRevision

        findState.show()

        #expect(finder.calls.count == callCount)
        #expect(findState.focusRevision == focusRevision + 1)
    }
}

@MainActor
private final class RecordingTerminalFinder: TerminalTextFinding {
    enum Call: Equatable {
        case find(String)
        case findAgain(String, TerminalFindDirection)
        case end
    }

    var calls: [Call] = []
    var onFindMatchCountChange: ((TerminalFindMatchCount?) -> Void)?
    let matchCount = TerminalFindMatchCount(total: 3, selectedNumber: 1, exceedsCountLimit: false)
    /// Reports `matchCount` from inside each call, as SwiftTerm does; Ghostty reports later.
    var reportsWhenCalled = true

    func findText(_ query: String) {
        calls.append(.find(query))
        if reportsWhenCalled { onFindMatchCountChange?(matchCount) }
    }

    func findTextAgain(_ query: String, direction: TerminalFindDirection) {
        calls.append(.findAgain(query, direction))
        if reportsWhenCalled { onFindMatchCountChange?(matchCount) }
    }

    func endTextFind() {
        calls.append(.end)
    }
}
