import AppKit
import Testing
@testable import JustSessions

/// Find in a Ghostty tab, which scrolls the selected match to the top of the view; see `SwiftTermTerminalFindTests`.
/// Each test waits for Ghostty's final layout before any output: a resize drops the selected match, so the next move
/// selects the newest again.
@MainActor
@Suite(.serialized)
struct GhosttyTerminalFindTests {
    private func firstShownLine(_ fixture: GhosttyTabFixture) -> String {
        fixture.screen.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    private func count(_ selectedNumber: Int?) -> TerminalFindMatchCount {
        TerminalFindMatchCount(total: 3, selectedNumber: selectedNumber, exceedsCountLimit: false)
    }

    @Test func movesGoTowardOlderOrNewerOutputFromTheNewestMatch() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.waitForLayout()
        fixture.view.inMemorySession.receive(TerminalFindFixtureOutput.linesWithThreeNeedles.joined(separator: "\r\n"))
        fixture.view.inMemorySession.waitForPendingOutput()
        var reportedCounts: [TerminalFindMatchCount?] = []
        fixture.view.onFindMatchCountChange = { reportedCounts.append($0) }

        fixture.view.findText("NEEDLE")
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-new") }
        try await expectEventually { reportedCounts.last == count(1) }

        fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-mid") }
        try await expectEventually { reportedCounts.last == count(2) }
        fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-old") }
        try await expectEventually { reportedCounts.last == count(3) }
        fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-new") }
        try await expectEventually { reportedCounts.last == count(1) }
        fixture.view.findTextAgain("needle", direction: .towardNewer)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-old") }
        try await expectEventually { reportedCounts.last == count(3) }
    }

    @Test func aQueryWithNoMatchCountsNoneAndEndingTheSearchCountsNothing() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.waitForLayout()
        fixture.view.inMemorySession.receive(TerminalFindFixtureOutput.linesWithThreeNeedles.joined(separator: "\r\n"))
        fixture.view.inMemorySession.waitForPendingOutput()
        var reportedCounts: [TerminalFindMatchCount?] = []
        fixture.view.onFindMatchCountChange = { reportedCounts.append($0) }

        fixture.view.findText("haystack")
        try await expectEventually { reportedCounts.last == TerminalFindMatchCount.none }

        fixture.view.endTextFind()
        try await expectEventually { reportedCounts.last == .some(nil) }
    }

    /// `search:` takes the rest of the binding action as its text, as typed.
    @Test func aQueryWithColonsAndBackslashesFindsItself() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.waitForLayout()
        var lines = (1...300).map { String(format: "line-%04d", $0) }
        lines[49] = #"line-0050 C:\Users\x41:found"#
        fixture.view.inMemorySession.receive(lines.joined(separator: "\r\n"))
        fixture.view.inMemorySession.waitForPendingOutput()

        fixture.view.findText(#"C:\Users\x41:found"#)

        try await expectEventually { firstShownLine(fixture).hasPrefix("line-0050") }
    }
}
