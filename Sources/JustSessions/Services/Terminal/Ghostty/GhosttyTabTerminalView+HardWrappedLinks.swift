import AppKit
import GhosttyTerminal

/// A ⌘-click on a link a CLI broke over rows opens all of it; see `HardWrappedLink`. Ghostty finds links one row at a
/// time, unlike SwiftTerm, which joins such rows itself. Ghostty handles the release first and reports the link it
/// found: the clicked row's part, or an OSC 8 hyperlink's target, which wins.
extension GhosttyTabTerminalView {
    /// The link a CLI broke over rows at `event`'s cell. Only while a program lays out its own screen: on the
    /// alternate screen, or while it takes the mouse, as tmux does in every CLI tab on this Mac. A shell's long line
    /// wraps at the edge by itself, and Ghostty joins that.
    func hardWrappedLink(under event: NSEvent) -> HardWrappedLink? {
        guard isOnAlternateScreen || terminalSurface?.isMouseCaptured == true, let cellGrid else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), let cell = cellGrid.cell(containing: point),
            let screenText = inMemorySession.readViewportText()
        else { return nil }
        return HardWrappedLink(
            rows: screenText.components(separatedBy: "\n"), columns: cellGrid.columns, row: cell.row, column: cell.column
        )
    }
}
