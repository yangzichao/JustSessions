import AppKit
import Carbon.HIToolbox
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct GhosttyTabLinkClickTests {
    @Test func aClickWithoutCommandStillGoesToTheProgramThatTakesTheMouse() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: #"printf '\033[?1000h\033[?1006hhttps://example.com/docs\r\n'; echo READY"#)
        try await expectEventually { fixture.screen.contains("READY") }

        try TerminalClick.click(fixture.view, column: 3, modifierFlags: [])

        // A press and a release in SGR form, `ESC [ < 0 ; column ; row M` and the same ending in `m`.
        try await expectEventually { fixture.receivedInput.hasSuffix("m") }
        #expect(fixture.receivedInput.hasPrefix("\u{1B}[<0;"))
        #expect(fixture.receivedInput.contains(";1M\u{1B}[<0;"))
    }

    @Test func aCommandClickOnALinkOpensItWithoutReachingTheProgram() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        var openedLinks: [String] = []
        fixture.view.onOpenLink = { openedLinks.append($0) }
        try await fixture.start(printing: #"printf '\033[?1000h\033[?1006hhttps://example.com/docs\r\n'; echo READY"#)
        try await expectEventually { fixture.screen.contains("READY") }

        try TerminalClick.click(fixture.view, column: 3, modifierFlags: .command)
        fixture.view.keyDown(with: SyntheticKey.event(keyCode: kVK_ANSI_X, characters: "x", window: fixture.window))

        try await expectEventually { fixture.receivedInput.contains("x") }
        #expect(fixture.receivedInput == "x")
        #expect(openedLinks == ["https://example.com/docs"])
    }
}
