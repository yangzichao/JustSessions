import AppKit
import GhosttyTerminal
import Testing

@testable import JustSessions

struct TerminalTestGrid {
    let columns: Int
    let cellSize: CGSize

    init(columns: Int, cellSize: CGSize) {
        self.columns = columns
        self.cellSize = cellSize
    }

    init(_ gridMetrics: TerminalGridMetrics, scale: CGFloat) {
        columns = Int(gridMetrics.columns)
        cellSize = CGSize(
            width: CGFloat(gridMetrics.cellWidthPixels) / scale, height: CGFloat(gridMetrics.cellHeightPixels) / scale
        )
    }

    func location(ofColumn column: Int, row: Int, in view: NSView) -> CGPoint {
        CGPoint(
            x: (CGFloat(column) + 0.5) * cellSize.width,
            y: view.bounds.height - (CGFloat(row) + 0.5) * cellSize.height
        )
    }
}

extension ClickableTerminal {
    /// The terminal's grid once it has one. Both engines measure cells in whole pixels at the window's scale. Ghostty
    /// reports its grid from the main queue a moment after the window holds the terminal, and lays a new terminal out
    /// twice, first at a provisional size, so this waits until the grid stays put.
    func grid() async throws -> TerminalTestGrid {
        let scale = window.backingScaleFactor
        switch view {
        case let swiftTermView as SelectableTerminalView:
            let terminal = swiftTermView.getTerminal()
            let cellPixels = try #require(swiftTermView.cellSizeInPixels(source: terminal))
            return TerminalTestGrid(
                columns: terminal.cols,
                cellSize: CGSize(width: CGFloat(cellPixels.width) / scale, height: CGFloat(cellPixels.height) / scale)
            )
        case let ghosttyView as GhosttyTabTerminalView:
            return TerminalTestGrid(try #require(await stableGridMetrics(of: ghosttyView)), scale: scale)
        default:
            Issue.record("A terminal of neither engine")
            return TerminalTestGrid(columns: 0, cellSize: .zero)
        }
    }

    private func stableGridMetrics(of view: GhosttyTabTerminalView) async throws -> TerminalGridMetrics? {
        var lastGridMetrics = view.gridMetrics
        var stableSince = ContinuousClock.now
        let deadline = ContinuousClock.now + .seconds(30)
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            if view.gridMetrics != lastGridMetrics {
                lastGridMetrics = view.gridMetrics
                stableSince = .now
            } else if lastGridMetrics != nil, ContinuousClock.now - stableSince > .milliseconds(300) {
                return lastGridMetrics
            }
        }
        return nil
    }
}
