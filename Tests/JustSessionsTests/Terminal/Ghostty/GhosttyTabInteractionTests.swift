import AppKit
import Testing
@testable import JustSessions

/// The Edit menu's Select All, Copy, and Paste in a Ghostty tab; see `TerminalInteractionTests` for SwiftTerm's.
/// Ghostty copies to and pastes from the general pasteboard only, so these tests put back what it held.
@MainActor
@Suite(.serialized)
struct GhosttyTabInteractionTests {
    @Test func selectAllSelectsTheOutputScrollbackIncluded() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        let lines = (1...300).map { String(format: "line-%04d", $0) }
        fixture.view.inMemorySession.receive(lines.joined(separator: "\r\n"))
        fixture.view.inMemorySession.waitForPendingOutput()
        #expect(!fixture.screen.contains("line-0001"))

        let selection = try #require(fixture.selectAllText())

        #expect(fixture.view.terminalSurface?.hasSelection() == true)
        #expect(selection.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) } == lines)
    }

    @Test func copyPutsTheSelectionOnThePasteboard() throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        let savedPasteboard = SavedGeneralPasteboard()
        defer { savedPasteboard.restore() }
        NSPasteboard.general.clearContents()
        fixture.view.inMemorySession.receive("Terminal output to copy")
        fixture.view.inMemorySession.waitForPendingOutput()
        fixture.view.selectAll(nil)

        fixture.view.copy(nil)

        #expect(NSPasteboard.general.string(forType: .string)?.contains("Terminal output to copy") == true)
    }

    @Test func pasteSendsThePasteboardText() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        let savedPasteboard = SavedGeneralPasteboard()
        defer { savedPasteboard.restore() }
        try await fixture.start(printing: "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("pasted text 你好", forType: .string)

        #expect(NSApp.sendAction(#selector(NSText.paste(_:)), to: fixture.view, from: nil))

        try await expectEventually { fixture.receivedInput == "pasted text 你好" }
    }

    /// The terminal's right-click menu calls these through `TabTerminalView`; see `TerminalContextMenu`.
    @Test func theRightClickMenusCopyAndPasteDoWhatTheEditMenusDo() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        let savedPasteboard = SavedGeneralPasteboard()
        defer { savedPasteboard.restore() }
        try await fixture.start(printing: "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }
        let terminalView: any TabTerminalView = fixture.view
        NSPasteboard.general.clearContents()
        terminalView.selectAll(terminalView)
        #expect(terminalView.selectionActive)

        terminalView.copy(terminalView)

        #expect(NSPasteboard.general.string(forType: .string)?.contains("READY") == true)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("pasted from the menu", forType: .string)

        terminalView.paste(terminalView)

        try await expectEventually { fixture.receivedInput == "pasted from the menu" }
    }

    /// Ghostty's own rules, which SwiftTerm doesn't follow: without bracketed paste a newline goes as Return, and
    /// Escape and other control characters go as spaces either way.
    @Test(arguments: [false, true])
    func ghosttyPastesNewlinesAsReturnAndControlCharactersAsSpaces(isBracketed: Bool) async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: (isBracketed ? "printf '\\033[?2004h'; " : "") + "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }

        fixture.view.paste(text: "a1\nb2\u{1B}[31mX")

        let expected = isBracketed ? "\u{1B}[200~a1\nb2 [31mX\u{1B}[201~" : "a1\rb2 [31mX"
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(fixture.receivedInput == expected)
    }
}

/// The general pasteboard's items, put back by `restore()`.
@MainActor
private struct SavedGeneralPasteboard {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init() {
        items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
        }
    }

    func restore() {
        NSPasteboard.general.clearContents()
        let restored = items.map { savedItem in
            let item = NSPasteboardItem()
            for (type, data) in savedItem { item.setData(data, forType: type) }
            return item
        }
        NSPasteboard.general.writeObjects(restored)
    }
}
