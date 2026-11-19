import AppKit
import Testing

@testable import JustSessions

/// ⌥← and ⌥→ alone reach the program as Esc b and Esc f, a word back and forward in a shell, from either engine,
/// whether or not Option is Meta (TRM-66, TRM-75). With Option off, a SwiftTerm tab sent `CSI 1;3D` and `CSI 1;3C`,
/// which zsh and bash typed into the line as `3D`.
@MainActor
@Suite(.serialized)
struct TerminalOptionWordMotionTests {
    @Test(arguments: TerminalEngine.allCases, [true, false])
    func optionLeftAndRightMoveAWord(_ engine: TerminalEngine, optionIsMeta: Bool) async throws {
        let fixture = try KeyRecordingTerminalFixture(engine: engine, optionIsMeta: optionIsMeta)
        defer { fixture.tearDown() }
        try await fixture.start()

        for key in [ModifiedNavigationKeyPress.Key.left, .right] {
            let press = ModifiedNavigationKeyPress(key: key, modifiers: .option)
            fixture.terminalView.keyDown(with: press.event(windowNumber: fixture.window.windowNumber))
        }

        let expected = "\u{1b}b\u{1b}f"
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(fixture.receivedInput == expected, "Received bytes: \(Array(fixture.receivedInput.utf8))")
    }
}
