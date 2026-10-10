import AppKit
import Testing
@testable import JustSessions

/// A right-click on a Ghostty tab's terminal shows the app's menu, as on a SwiftTerm one, never Ghostty's own, and the
/// program gets no click; see `TerminalRightClickTests` for the menu on both engines.
@MainActor
@Suite(.serialized)
struct GhosttyTabRightClickTests {
    /// Over a selection, Ghostty would offer its own menu, with Copy only.
    @Test func overASelectionTheMenuIsTheAppsNotGhosttys() throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.inMemorySession.receive("Selected output")
        fixture.view.inMemorySession.waitForPendingOutput()
        fixture.view.selectAll(nil)
        try #require(fixture.view.selectionActive)
        let appMenu = NSMenu(title: "App")
        fixture.view.makeContextMenu = { appMenu }

        #expect(fixture.view.menu(for: rightMouseEvent(.rightMouseDown, in: fixture)) === appMenu)
    }

    /// A program that turned on mouse reporting would get the click from Ghostty.
    @Test func aRightClickShowsTheAppsMenuAndTheProgramGetsNothing() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: "printf '\\033[?1000hREADY'")
        try await expectEventually { fixture.screen.contains("READY") }
        let appMenu = NSMenu(title: "App")
        fixture.view.makeContextMenu = { appMenu }
        var shownMenus: [NSMenu] = []
        fixture.view.popUpContextMenu = { menu, event, view in
            #expect(event.type == .rightMouseDown && view === fixture.view)
            shownMenus.append(menu)
        }
        var focusCount = 0
        fixture.view.onFocus = { focusCount += 1 }

        fixture.view.rightMouseDown(with: rightMouseEvent(.rightMouseDown, in: fixture))
        fixture.view.rightMouseUp(with: rightMouseEvent(.rightMouseUp, in: fixture))

        #expect(shownMenus.count == 1 && shownMenus.first === appMenu)
        #expect(focusCount == 1)
        try await Task.sleep(for: .milliseconds(300))
        #expect(fixture.receivedInput.isEmpty)
    }

    /// Without the app's menu, as in the Settings preview, Ghostty handles the click itself.
    @Test func withoutTheAppsMenuGhosttyTakesTheClick() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: "printf '\\033[?1000hREADY'")
        try await expectEventually { fixture.screen.contains("READY") }

        fixture.view.rightMouseDown(with: rightMouseEvent(.rightMouseDown, in: fixture))
        fixture.view.rightMouseUp(with: rightMouseEvent(.rightMouseUp, in: fixture))

        // X10 mouse reports: a right press (button 2) and a release.
        try await expectEventually { fixture.receivedInput.hasPrefix("\u{1B}[M\"") }
    }

    private func rightMouseEvent(_ type: NSEvent.EventType, in fixture: GhosttyTabFixture) -> NSEvent {
        let point = fixture.view.convert(NSPoint(x: 40, y: fixture.view.bounds.height - 40), to: nil)
        return NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: fixture.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )!
    }
}
