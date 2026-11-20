import CoreGraphics
import GhosttyTerminal

struct GhosttyZeroPaddingCellGrid {
    static let windowPadding = 0

    let columns: Int
    let rows: Int
    private let cellWidthPixels: Int
    private let cellHeightPixels: Int
    private let viewHeight: CGFloat
    private let backingScaleFactor: CGFloat

    init?(metrics: TerminalGridMetrics?, viewHeight: CGFloat, backingScaleFactor: CGFloat) {
        guard let metrics, metrics.cellWidthPixels > 0, metrics.cellHeightPixels > 0 else { return nil }
        columns = Int(metrics.columns)
        rows = Int(metrics.rows)
        cellWidthPixels = Int(metrics.cellWidthPixels)
        cellHeightPixels = Int(metrics.cellHeightPixels)
        self.viewHeight = viewHeight
        self.backingScaleFactor = backingScaleFactor
    }

    func cell(containing pointInView: CGPoint) -> TerminalCellPosition? {
        let column = Int(pointInView.x * backingScaleFactor) / cellWidthPixels
        let row = Int((viewHeight - pointInView.y) * backingScaleFactor) / cellHeightPixels
        guard column < columns, row < rows else { return nil }
        return TerminalCellPosition(column: column, row: row)
    }

    func cell(withBottomLeftCornerNear pointInView: CGPoint) -> TerminalCellPosition? {
        let column = Int(pointInView.x * backingScaleFactor / CGFloat(cellWidthPixels))
        let rowsAboveThePoint = (viewHeight - pointInView.y) * backingScaleFactor / CGFloat(cellHeightPixels)
        let row = Int(rowsAboveThePoint.rounded()) - 1
        guard (0..<columns).contains(column), (0..<rows).contains(row) else { return nil }
        return TerminalCellPosition(column: column, row: row)
    }

    func frame(ofColumns columnRange: Range<Int>, inRow row: Int) -> CGRect {
        let cellWidth = CGFloat(cellWidthPixels) / backingScaleFactor
        let cellHeight = CGFloat(cellHeightPixels) / backingScaleFactor
        return CGRect(
            x: CGFloat(columnRange.lowerBound) * cellWidth,
            y: viewHeight - CGFloat(row + 1) * cellHeight,
            width: CGFloat(columnRange.count) * cellWidth,
            height: cellHeight
        )
    }
}
