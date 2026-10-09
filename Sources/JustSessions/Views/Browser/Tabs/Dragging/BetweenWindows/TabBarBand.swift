import CoreGraphics

/// The strip along a workspace window's top edge where its tab bar runs, as a tab dragged between windows finds it, in
/// screen coordinates. A window with no tabs open has the strip too, empty. A tab dragged onto it joins the bar, and
/// stays until the pointer goes further above or below the bar than `detachDistance`, or past either side of the
/// window, as Chrome's tab strip holds a dragged tab within `kVerticalDetachMagnetism`.
struct TabBarBand {
    /// The tab bar's height: the space above the tabs, and the tabs.
    static let height = WorkspaceTabMetrics.topInset + WorkspaceTabMetrics.height
    static let detachDistance: CGFloat = 15

    let windowFrame: CGRect

    /// A tab dragged here joins the bar.
    func takesTab(at point: CGPoint) -> Bool {
        isBetweenSides(point) && point.y <= windowFrame.maxY && point.y >= windowFrame.maxY - Self.height
    }

    /// A tab in the bar stays in it while dragged here.
    func holdsTab(at point: CGPoint) -> Bool {
        isBetweenSides(point)
            && point.y <= windowFrame.maxY + Self.detachDistance
            && point.y >= windowFrame.maxY - Self.height - Self.detachDistance
    }

    private func isBetweenSides(_ point: CGPoint) -> Bool {
        point.x >= windowFrame.minX && point.x <= windowFrame.maxX
    }
}
