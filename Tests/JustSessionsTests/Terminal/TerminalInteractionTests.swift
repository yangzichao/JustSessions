import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TerminalInteractionTests {
    @Test func terminalOutputCanBeSelectedWhileMouseReportingStaysOn() {
        let terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        terminalView.feed(text: "Terminal output to copy")
        terminalView.selectAll()

        #expect(terminalView.allowMouseReporting)
        #expect(terminalView.getSelection()?.contains("Terminal output to copy") == true)

        terminalView.selectNone()
        #expect(terminalView.getSelection() == nil)
    }
}
