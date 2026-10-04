import SwiftUI

/// The strip along the window's top edge that holds the close, minimize, and zoom buttons and the sidebar toggle.
/// The tab bar shares it: its tabs sit on the strip's center line and, while the sidebar is hidden, start past the
/// toggle.
struct TitleBarRow: Equatable {
    /// The title bar's height, or in full screen the height of the strip left for the toggle.
    var height: CGFloat
    /// The toggle's trailing edge, measured from the window's leading edge.
    var toggleTrailingEdge: CGFloat
}

extension EnvironmentValues {
    @Entry var titleBarRow = TitleBarRow(height: 28, toggleTrailingEdge: 106)
}
