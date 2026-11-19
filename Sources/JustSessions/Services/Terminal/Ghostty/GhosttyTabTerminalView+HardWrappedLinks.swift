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
        guard isOnAlternateScreen || terminalSurface?.isMouseCaptured == true, let gridMetrics,
            gridMetrics.cellWidthPixels > 0, gridMetrics.cellHeightPixels > 0
        else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return nil }
        // Ghostty lays the text out from the view's top left corner, with no padding, in cells of whole pixels at the
        // window's scale.
        let scale = window?.backingScaleFactor ?? 1
        let column = Int(point.x * scale) / Int(gridMetrics.cellWidthPixels)
        let row = Int((bounds.height - point.y) * scale) / Int(gridMetrics.cellHeightPixels)
        guard column < Int(gridMetrics.columns), row < Int(gridMetrics.rows),
            let screenText = inMemorySession.readViewportText()
        else { return nil }
        return HardWrappedLink(
            rows: screenText.components(separatedBy: "\n"), columns: Int(gridMetrics.columns), row: row, column: column
        )
    }
}

/// Ghostty reports its grid here each time it lays the text out, with the cell size a click's cell is found by. The
/// in-memory session's viewport, which the pseudo-terminal gets, leaves the cell size out.
extension GhosttyTabTerminalView: TerminalSurfaceGridResizeDelegate {
    func terminalDidResize(_ size: TerminalGridMetrics) {
        gridMetrics = size
    }
}
