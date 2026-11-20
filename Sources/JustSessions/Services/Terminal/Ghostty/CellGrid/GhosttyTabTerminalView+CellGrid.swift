import AppKit
import GhosttyTerminal

extension GhosttyTabTerminalView: TerminalSurfaceGridResizeDelegate {
    func terminalDidResize(_ size: TerminalGridMetrics) {
        gridMetrics = size
    }

    var cellGrid: GhosttyZeroPaddingCellGrid? {
        GhosttyZeroPaddingCellGrid(metrics: gridMetrics, viewHeight: bounds.height, backingScaleFactor: window?.backingScaleFactor ?? 1)
    }
}
