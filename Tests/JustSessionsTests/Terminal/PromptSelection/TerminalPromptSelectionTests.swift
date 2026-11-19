import AppKit
import Testing

@testable import JustSessions

/// ⌘A in either engine's terminal selects the prompt Claude Code draws, and the keys that follow edit it through the
/// keys the CLI reads; see `TerminalPromptSelection`. A process that records the bytes it gets stands in for the CLI,
/// and the test draws the CLI's prompt in the terminal itself.
@MainActor
@Suite(.serialized)
struct TerminalPromptSelectionTests {
    typealias Key = PromptSelectionTestKey

    @Test(arguments: TerminalEngine.allCases)
    func commandASelectsOnlyThePromptAndCommandCCopiesIt(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango", "second line"])

        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        #expect(fixture.promptSelection.selectedPrompt?.text == "kiwi mango\nsecond line")
        #expect(!fixture.terminalView.selectionActive)
        #expect(fixture.terminalView.subviews.contains { $0 is TerminalPromptSelectionOverlay })

        #expect(fixture.promptSelection.handleKeyDown(Key.command("c", windowNumber: fixture.windowNumber)))
        #expect(fixture.pasteboard.string(forType: .string) == "kiwi mango\nsecond line")
        #expect(fixture.promptSelection.isActive)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fixture.recorder.receivedInput.isEmpty)
    }

    @Test(arguments: TerminalEngine.allCases)
    func deleteSendsTheKeysThatClearThePrompt(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        let prompt = try #require(fixture.promptSelection.selectedPrompt)

        #expect(fixture.promptSelection.handleKeyDown(Key.delete(windowNumber: fixture.windowNumber)))

        #expect(!fixture.promptSelection.isActive)
        #expect(!fixture.terminalView.subviews.contains { $0 is TerminalPromptSelectionOverlay })
        try await fixture.expectInput(CLIPromptEditingKeys.clearing(prompt))
    }

    /// The typed key goes on to the terminal after the keys that clear the prompt, in that order, also from Ghostty,
    /// which sends both from its own thread.
    @Test(arguments: TerminalEngine.allCases)
    func typingReplacesThePrompt(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        let prompt = try #require(fixture.promptSelection.selectedPrompt)
        let typedKey = Key.typing("k", windowNumber: fixture.windowNumber)

        #expect(!fixture.promptSelection.handleKeyDown(typedKey))
        fixture.terminalView.keyDown(with: typedKey)

        try await fixture.expectInput(CLIPromptEditingKeys.clearing(prompt) + "k")
    }

    @Test(arguments: TerminalEngine.allCases)
    func leftArrowMovesToThePromptsStart(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango", "second line"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        let prompt = try #require(fixture.promptSelection.selectedPrompt)

        #expect(fixture.promptSelection.handleKeyDown(Key.leftArrow(windowNumber: fixture.windowNumber)))

        try await fixture.expectInput(CLIPromptEditingKeys.movingToStart(of: prompt))
    }

    /// Edit → Paste chosen with the pointer reaches neither the keys nor Ghostty's own paste, so the selection hears the
    /// menu item's action instead.
    @Test(arguments: TerminalEngine.allCases)
    func editMenuPasteReplacesThePrompt(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        let prompt = try #require(fixture.promptSelection.selectedPrompt)
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")

        NotificationCenter.default.post(name: NSMenu.willSendActionNotification, object: NSMenu(), userInfo: ["MenuItem": pasteItem])

        try await expectEventually { !fixture.promptSelection.isActive }
        try await fixture.expectInput(CLIPromptEditingKeys.clearing(prompt))
    }

    /// Edit → Copy is on while the prompt is selected, though the terminal's own selection is empty.
    @Test(arguments: TerminalEngine.allCases)
    func editMenuCopyIsOnWhileThePromptIsSelected(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        let editMenu = NSMenu()
        let copyItem = editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        copyItem.target = fixture.terminalView

        editMenu.update()

        #expect(copyItem.isEnabled)
    }

    /// Any other key ends the selection and goes to the CLI as usual.
    @Test(arguments: TerminalEngine.allCases)
    func otherKeysEndTheSelection(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))

        #expect(!fixture.promptSelection.handleKeyDown(Key.upArrow(windowNumber: fixture.windowNumber)))

        #expect(!fixture.promptSelection.isActive)
        try await Task.sleep(for: .milliseconds(100))
        #expect(fixture.recorder.receivedInput.isEmpty)
    }

    /// The selection follows the prompt while it shows the same text, and ends once the text changes.
    @Test(arguments: TerminalEngine.allCases)
    func theSelectionEndsWhenThePromptChanges(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        #expect(fixture.terminalView.performKeyEquivalent(with: fixture.commandA))

        try fixture.drawClaudeCodePrompt(["kiwi mango"], topRow: 3)
        fixture.promptSelection.checkPromptOnScreen()
        #expect(fixture.promptSelection.selectedPrompt?.lines.first?.row == 4)

        try fixture.drawClaudeCodePrompt(["kiwi mangos"], topRow: 3)
        fixture.promptSelection.checkPromptOnScreen()
        #expect(!fixture.promptSelection.isActive)
    }

    /// Without a prompt with text in it, or for a CLI without a layout, ⌘A goes on to Edit → Select All.
    @Test(arguments: TerminalEngine.allCases)
    func withoutAPromptCommandAGoesOnToSelectAll(_ engine: TerminalEngine) async throws {
        let fixture = try await PromptDrawingFixture(engine: engine)
        defer { fixture.tearDown() }
        try fixture.drawClaudeCodePrompt([""])
        #expect(!fixture.terminalView.performKeyEquivalent(with: fixture.commandA))

        try fixture.drawClaudeCodePrompt(["kiwi mango"])
        fixture.promptSelection.layout = nil
        #expect(!fixture.terminalView.performKeyEquivalent(with: fixture.commandA))
        #expect(!fixture.promptSelection.isActive)
    }
}

/// A terminal of either engine, whose prompt selection reads Claude Code's prompt, with a process recording its input.
@MainActor
final class PromptDrawingFixture {
    let recorder: KeyRecordingTerminalFixture
    let pasteboard = NSPasteboard.withUniqueName()
    private let columnCount: Int

    init(engine: TerminalEngine) async throws {
        recorder = try KeyRecordingTerminalFixture(engine: engine)
        try await recorder.start()
        let terminal = try #require(recorder.terminalView as? any PromptSelectableTerminal)
        columnCount = try #require(await Self.stableColumnCount(of: terminal))
        promptSelection.layout = .claudeCode
        promptSelection.pasteboard = pasteboard
    }

    /// Ghostty lays a new terminal out twice, first at a provisional size, so the grid has to stay put a moment.
    private static func stableColumnCount(of terminal: any PromptSelectableTerminal) async throws -> Int? {
        var lastColumnCount = terminal.screenForPromptSelection()?.columnCount
        var stableSince = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(30)
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            let columnCount = terminal.screenForPromptSelection()?.columnCount
            if columnCount != lastColumnCount {
                lastColumnCount = columnCount
                stableSince = .now
            } else if lastColumnCount != nil, ContinuousClock.now - stableSince > .milliseconds(300) {
                return lastColumnCount
            }
        }
        return nil
    }

    var terminalView: any TabTerminalView { recorder.terminalView }
    var promptSelection: TerminalPromptSelection { recorder.terminalView.promptSelection }
    var windowNumber: Int { recorder.window.windowNumber }
    var commandA: NSEvent { PromptSelectionTestKey.command("a", windowNumber: windowNumber) }

    /// Claude Code's prompt between two rules, its first row after `❯`, with the caret after its last character.
    func drawClaudeCodePrompt(_ lines: [String], topRow: Int = 0) throws {
        let rule = String(repeating: "─", count: columnCount)
        let rows = [rule] + lines.enumerated().map { index, line in (index == 0 ? "❯\u{A0}" : "  ") + line } + [rule]
        var output = "\u{1B}[2J"
        for (offset, row) in rows.enumerated() {
            output += "\u{1B}[\(topRow + offset + 1);1H" + row
        }
        let caretRow = topRow + lines.count
        let caretColumn = 2 + TerminalScreenRow(lines.last ?? "").textWidth
        output += "\u{1B}[\(caretRow + 1);\(caretColumn + 1)H"
        feedOutput(output, to: terminalView)
    }

    func expectInput(_ expected: String) async throws {
        try await expectEventually { self.recorder.receivedInput.utf8.count >= expected.utf8.count }
        #expect(recorder.receivedInput == expected, "Received bytes: \(Array(recorder.receivedInput.utf8))")
    }

    func tearDown() {
        promptSelection.cancel()
        pasteboard.releaseGlobally()
        recorder.tearDown()
    }
}
