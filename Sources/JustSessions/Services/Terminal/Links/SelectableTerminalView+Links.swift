import AppKit
import SwiftTerm

extension SelectableTerminalView {
    func link(under event: NSEvent) -> String? {
        let point = convert(event.locationInWindow, from: nil)
        // SwiftTerm keeps its cell size to itself, but reports it in pixels, which are whole since it snaps cells to
        // the pixel grid, at the window's scale.
        let scale = window?.backingScaleFactor ?? 1
        guard bounds.contains(point), let cellPixels = cellSizeInPixels(source: terminal), cellPixels.width > 0,
            cellPixels.height > 0
        else { return nil }
        let column = Int(point.x * scale) / cellPixels.width
        let row = Int((bounds.height - point.y) * scale) / cellPixels.height
        guard column < terminal.cols, row < terminal.rows else { return nil }
        return terminal.link(at: .screen(Position(col: column, row: row)), mode: .explicitAndImplicit)
    }
}
