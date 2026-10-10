import Foundation
import Testing
@testable import JustSessions

/// A program in a Ghostty tab hears whether the terminal is light or dark once, from the tab, as in a SwiftTerm tab.
/// Ghostty would also answer, always saying light, and report again on each change to its configuration.
@MainActor
@Suite(.serialized)
struct GhosttyTabThemeReportTests {
    @Test(arguments: [TerminalAppearanceMode.light, .dark])
    func aProgramThatAsksGetsOneAnswer(mode: TerminalAppearanceMode) async throws {
        let fixture = try GhosttyTabFixture(mode: mode)
        defer { fixture.tearDown() }

        try await fixture.start(printing: "printf '\\033[?996n'")

        let answer = TerminalThemeReporting.report(isDark: mode == .dark)
        try await expectEventually(timeout: .seconds(30)) { !fixture.receivedInput.isEmpty }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == answer)
    }

    @Test func aSubscribedProgramGetsOneReportForEachThemeChange() async throws {
        let fixture = try GhosttyTabFixture(mode: .light)
        defer { fixture.tearDown() }
        try await fixture.start(printing: "printf '\\033[?2031hSUBSCRIBED'")
        try await expectEventually(timeout: .seconds(30)) { fixture.screen.contains("SUBSCRIBED") }

        fixture.appearanceStore.setMode(.dark)

        let dark = TerminalThemeReporting.report(isDark: true)
        try await expectEventually(timeout: .seconds(30)) { !fixture.receivedInput.isEmpty }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == dark)

        fixture.appearanceStore.setMode(.light)

        let light = TerminalThemeReporting.report(isDark: false)
        try await expectEventually(timeout: .seconds(30)) { fixture.receivedInput.utf8.count > dark.utf8.count }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == dark + light)
    }
}
