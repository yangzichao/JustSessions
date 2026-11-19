import CoreGraphics

enum TerminalSplitLayout {
    static let contentInset: CGFloat = 8
    static let resizeAreaWidth: CGFloat = 10
    static let minimumPaneWidth: CGFloat = 200
    static let minimumPaneHeight: CGFloat = 120
    static let evenFraction: CGFloat = 0.5
    static let snapDistance: CGFloat = 15

    struct PaneLengths: Equatable {
        var leading: CGFloat
        var trailing: CGFloat
    }

    struct Frames: Equatable {
        var left: CGRect
        var resizeArea: CGRect
        var right: CGRect
    }

    static func minimumPaneLength(_ orientation: TerminalSplit.Orientation) -> CGFloat {
        orientation == .sideBySide ? minimumPaneWidth : minimumPaneHeight
    }

    static func totalLength(of size: CGSize, _ orientation: TerminalSplit.Orientation) -> CGFloat {
        orientation == .sideBySide ? size.width : size.height
    }

    static func availableLength(totalLength: CGFloat) -> CGFloat {
        max(totalLength - 2 * contentInset - resizeAreaWidth, 0)
    }

    static func clampedFraction(
        _ fraction: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation
    ) -> CGFloat {
        let availableLength = availableLength(totalLength: totalLength)
        let minimumLength = minimumPaneLength(orientation)
        guard availableLength >= minimumLength * 2 else { return evenFraction }
        let minimumFraction = minimumLength / availableLength
        return min(max(fraction, minimumFraction), 1 - minimumFraction)
    }

    static func paneLengths(
        fraction: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation
    ) -> PaneLengths {
        let availableLength = availableLength(totalLength: totalLength)
        let leading = (availableLength * clampedFraction(fraction, totalLength: totalLength, orientation: orientation)).rounded()
        return PaneLengths(leading: leading, trailing: availableLength - leading)
    }

    static func frames(fraction: CGFloat, size: CGSize, orientation: TerminalSplit.Orientation) -> Frames {
        let lengths = paneLengths(fraction: fraction, totalLength: totalLength(of: size, orientation), orientation: orientation)
        switch orientation {
        case .sideBySide:
            let height = max(size.height - 2 * contentInset, 0)
            let left = CGRect(x: contentInset, y: contentInset, width: lengths.leading, height: height)
            let resizeArea = CGRect(x: left.maxX, y: contentInset, width: resizeAreaWidth, height: height)
            let right = CGRect(x: resizeArea.maxX, y: contentInset, width: lengths.trailing, height: height)
            return Frames(left: left, resizeArea: resizeArea, right: right)
        case .stacked:
            let width = max(size.width - 2 * contentInset, 0)
            let top = CGRect(x: contentInset, y: contentInset, width: width, height: lengths.leading)
            let resizeArea = CGRect(x: contentInset, y: top.maxY, width: width, height: resizeAreaWidth)
            let bottom = CGRect(x: contentInset, y: resizeArea.maxY, width: width, height: lengths.trailing)
            return Frames(left: top, resizeArea: resizeArea, right: bottom)
        }
    }

    static func fraction(
        startingAt startFraction: CGFloat,
        draggedBy delta: CGFloat,
        totalLength: CGFloat,
        orientation: TerminalSplit.Orientation
    ) -> CGFloat {
        let availableLength = availableLength(totalLength: totalLength)
        guard availableLength > 0 else { return evenFraction }
        let leadingLength = startFraction * availableLength + delta
        guard abs(leadingLength - evenFraction * availableLength) >= snapDistance else { return evenFraction }
        return clampedFraction(leadingLength / availableLength, totalLength: totalLength, orientation: orientation)
    }
}
