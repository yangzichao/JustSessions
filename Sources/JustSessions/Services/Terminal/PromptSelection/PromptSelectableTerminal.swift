import AppKit

@MainActor
protocol PromptSelectableTerminal: NSView {
    func screenForPromptSelection() -> TerminalScreen?
    func frame(ofCells columns: Range<Int>, inRow row: Int) -> NSRect?
    func typeForPromptSelection(_ keys: String)
    func selectAllTerminalText()
    /// Whether the terminal's own selection holds text. Ghostty offers no way to end it but a click or a typed key.
    var selectionActive: Bool { get }
    func hasMarkedText() -> Bool
    var promptSelectionTextStyle: PromptSelectionTextStyle { get }
}

struct PromptSelectionTextStyle {
    let font: NSFont
    let backgroundColor: NSColor
    let foregroundColor: NSColor
}
