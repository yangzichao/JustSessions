import CoreGraphics

/// Lays a pane tree out in a rectangle: every pane's frame plus one divider per split, all on whole points so
/// pane edges and hairlines sit on the pixel grid.
enum WorkspacePaneGeometry {
    /// The grab area each divider gets; the hairline is drawn centered inside it.
    static let dividerThickness: CGFloat = 6
    /// No pane shrinks below this while a divider drags, so its content stays usable.
    static let minimumPaneLength: CGFloat = 120

    struct Divider: Equatable {
        /// Index for `WorkspacePaneLayout.settingFraction(_:atSplitIndex:)`, in the same in-order numbering.
        let splitIndex: Int
        /// True for side-by-side panes, whose divider moves left and right.
        let isHorizontal: Bool
        let rect: CGRect
        /// The whole split's rectangle, for turning a drag position into a fraction.
        let splitBounds: CGRect
    }

    struct Resolution: Equatable {
        var paneRects: [WorkspacePaneContent: CGRect] = [:]
        var dividers: [Divider] = []
    }

    static func resolve(_ layout: WorkspacePaneLayout, in bounds: CGRect) -> Resolution {
        var resolution = Resolution()
        var counter = 0
        resolve(layout, in: bounds, counter: &counter, into: &resolution)
        return resolution
    }

    /// The fraction for a divider dragged so its leading pane would be `leadingLength` points long, kept to whole
    /// points and away from the edges by the minimum pane length, as far as the split has room for it.
    static func fraction(forLeadingLength leadingLength: CGFloat, in splitBounds: CGRect, isHorizontal: Bool) -> Double {
        let available = max(1, (isHorizontal ? splitBounds.width : splitBounds.height) - dividerThickness)
        let minimum = min(minimumPaneLength, (available / 2).rounded(.down))
        let clamped = min(max(leadingLength.rounded(), minimum), available - minimum)
        return clamped / available
    }

    private static func resolve(
        _ layout: WorkspacePaneLayout,
        in bounds: CGRect,
        counter: inout Int,
        into resolution: inout Resolution
    ) {
        switch layout {
        case .pane(let content):
            resolution.paneRects[content] = bounds
        case .split(let split):
            let available = max(0, (split.isHorizontal ? bounds.width : bounds.height) - Self.dividerThickness)
            let leadingLength = (available * split.fraction).rounded()
            let leadingRect: CGRect
            let dividerRect: CGRect
            let trailingRect: CGRect
            if split.isHorizontal {
                leadingRect = CGRect(x: bounds.minX, y: bounds.minY, width: leadingLength, height: bounds.height)
                dividerRect = CGRect(x: leadingRect.maxX, y: bounds.minY, width: Self.dividerThickness, height: bounds.height)
                trailingRect = CGRect(x: dividerRect.maxX, y: bounds.minY, width: available - leadingLength, height: bounds.height)
            } else {
                leadingRect = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: leadingLength)
                dividerRect = CGRect(x: bounds.minX, y: leadingRect.maxY, width: bounds.width, height: Self.dividerThickness)
                trailingRect = CGRect(x: bounds.minX, y: dividerRect.maxY, width: bounds.width, height: available - leadingLength)
            }
            // The same order `settingFraction(_:atSplitIndex:)` numbers splits in: leading subtree, this split, trailing.
            resolve(split.leading, in: leadingRect, counter: &counter, into: &resolution)
            let splitIndex = counter
            counter += 1
            resolution.dividers.append(Divider(
                splitIndex: splitIndex, isHorizontal: split.isHorizontal, rect: dividerRect, splitBounds: bounds
            ))
            resolve(split.trailing, in: trailingRect, counter: &counter, into: &resolution)
        }
    }
}
