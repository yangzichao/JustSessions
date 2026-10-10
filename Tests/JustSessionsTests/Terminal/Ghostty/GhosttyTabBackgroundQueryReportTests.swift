import Foundation
import Testing
@testable import JustSessions

/// A Ghostty tab owed a theme report after the next background query, as `ConversationStore+RemoteTmuxColors` makes it
/// for tmux before 3.6, sends it right after Ghostty's own answer to that query, as a SwiftTerm tab does: the program
/// gets the answer first, then the report. See `ThemeReportAfterBackgroundQueryTests` for the reporting itself.
@MainActor
@Suite(.serialized)
struct GhosttyTabBackgroundQueryReportTests {
    /// The query ended by `ESC \` or by BEL, which Ghostty ends its answer with too.
    @Test(arguments: [("\\033\\\\", "\u{1B}\\"), ("\\007", "\u{07}")])
    func theOwedReportFollowsGhosttysAnswerToTheNextQueryOnly(terminator: (printed: String, answered: String)) async throws {
        let fixture = try GhosttyTabFixture(mode: .dark)
        defer { fixture.tearDown() }
        let query = "printf '\\033]11;?\(terminator.printed)'"
        try await fixture.start(printing: "wait_for owed; \(query); wait_for again; \(query)")
        let answer = Self.backgroundAnswer(of: fixture, terminator: terminator.answered)
        let report = TerminalThemeReporting.report(isDark: true)

        fixture.view.reportThemeAfterNextBackgroundQuery()
        fixture.signal("owed")

        try await expectEventually(timeout: .seconds(30)) { fixture.receivedInput.utf8.count >= (answer + report).utf8.count }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == answer + report)
        #expect(!fixture.view.reportsThemeAfterNextBackgroundQuery)

        fixture.signal("again")

        try await expectEventually(timeout: .seconds(30)) { fixture.receivedInput.utf8.count >= (answer + report + answer).utf8.count }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == answer + report + answer)
    }

    @Test func aCancelledReportIsNotSent() async throws {
        let fixture = try GhosttyTabFixture(mode: .light)
        defer { fixture.tearDown() }
        try await fixture.start(printing: "wait_for asked; printf '\\033]11;?\\007'")
        let answer = Self.backgroundAnswer(of: fixture, terminator: "\u{07}")

        fixture.view.reportThemeAfterNextBackgroundQuery()
        fixture.view.cancelThemeReportAfterNextBackgroundQuery()
        fixture.signal("asked")

        try await expectEventually(timeout: .seconds(30)) { !fixture.receivedInput.isEmpty }
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput == answer)
    }

    /// A program that subscribed to theme changes hears of a light/dark change itself, so only an unsubscribed one
    /// needs the tab to pass it on; see `UnheardLightDarkChangeTests` for a terminal that runs nothing.
    @Test func aSubscribedProgramHearsTheLightDarkChangeItself() async throws {
        let fixture = try GhosttyTabFixture(mode: .light)
        defer { fixture.tearDown() }
        var unheardChangeCount = 0
        fixture.view.onUnheardLightDarkChange = { unheardChangeCount += 1 }
        try await fixture.start(printing: "printf '\\033[?2031hSUBSCRIBED'")
        try await expectEventually(timeout: .seconds(30)) { fixture.screen.contains("SUBSCRIBED") }

        fixture.appearanceStore.setMode(.dark)

        try await expectEventually(timeout: .seconds(30)) { !fixture.receivedInput.isEmpty }
        #expect(fixture.receivedInput == TerminalThemeReporting.report(isDark: true))
        #expect(unheardChangeCount == 0)
    }

    /// Ghostty's 16-bit answer, `OSC 11 ; rgb:rrrr/gggg/bbbb`, for the background the fixture's settings give.
    private static func backgroundAnswer(of fixture: GhosttyTabFixture, terminator: String) -> String {
        let preferences = fixture.appearanceStore.preferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(effectiveAppearance: fixture.view.effectiveAppearance)
        let background = preferences.colorVariants(appTheme: fixture.themeStore.terminalTheme).palette(usesDarkColors: usesDarkColors).background
        let components = [16, 8, 0].map { String(format: "%04x", ((background >> UInt32($0)) & 0xFF) * 257) }
        return "\u{1B}]11;rgb:" + components.joined(separator: "/") + terminator
    }
}
