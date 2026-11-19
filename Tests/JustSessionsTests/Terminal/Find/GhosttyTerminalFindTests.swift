import AppKit
import Testing

@testable import JustSessions

/// Each test waits for Ghostty's final layout before any output: a resize drops the selected match, so the next move
/// selects the newest again.
@MainActor
@Suite(.serialized)
struct GhosttyTerminalFindTests {
    private func firstShownLine(_ fixture: GhosttyTabFixture) -> String {
        fixture.screen.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    @Test func movesGoTowardOlderOrNewerOutputFromTheNewestMatch() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.waitForLayout()
        fixture.view.inMemorySession.receive(TerminalFindFixtureOutput.linesWithThreeNeedles.joined(separator: "\r\n"))
        fixture.view.inMemorySession.waitForPendingOutput()

        #expect(fixture.view.findText("NEEDLE") == nil)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-new") }

        _ = fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-mid") }
        _ = fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-old") }
        _ = fixture.view.findTextAgain("needle", direction: .towardOlder)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-new") }
        _ = fixture.view.findTextAgain("needle", direction: .towardNewer)
        try await expectEventually { firstShownLine(fixture).hasSuffix("needle-old") }
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

        _ = fixture.view.findText(#"C:\Users\x41:found"#)

        try await expectEventually { firstShownLine(fixture).hasPrefix("line-0050") }
    }
}
