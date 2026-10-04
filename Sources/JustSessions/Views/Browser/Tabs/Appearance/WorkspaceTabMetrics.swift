import CoreGraphics

/// Sizes shared by the tab bar, its tabs, and its group labels.
enum WorkspaceTabMetrics {
    /// Every tab is this wide, as in Chrome; a longer title is cut short.
    static let width: CGFloat = 200
    /// From a tab's top to the bottom of the tab bar, where the selected tab meets its terminal.
    static let height: CGFloat = 28
    /// Space between the window's top edge and the tabs.
    static let topInset: CGFloat = 4
    static let cornerRadius: CGFloat = 8
    /// How far the selected tab's feet curve out past its sides at the bottom.
    static let footRadius: CGFloat = 6
}
