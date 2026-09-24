import AppKit
import Testing
@testable import CocaCodex

@MainActor
struct TerminalInteractionTests {
    @Test func selectingTerminalOutputUpdatesCopyAvailability() {
        let terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var hasSelection = false
        terminalView.onSelectionChanged = { hasSelection = $0 }

        terminalView.feed(text: "Terminal output to copy")
        terminalView.selectAll()

        #expect(!terminalView.allowMouseReporting)
        #expect(hasSelection)
        #expect(terminalView.getSelection()?.contains("Terminal output to copy") == true)

        terminalView.selectNone()
        #expect(!hasSelection)
    }
}
