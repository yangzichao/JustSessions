import CoreGraphics

/// Sizes shared by the tab bar, its tabs, and its group labels.
enum WorkspaceTabMetrics {
    /// A tab's width while every tab fits in the bar. More tabs narrow together, as in Chrome.
    static let maximumWidth: CGFloat = 200
    /// The narrowest a tab gets: its status and the start of its title still show. Past this, the bar scrolls.
    static let minimumWidth: CGFloat = 72
    /// Tabs narrower than this show their × only when selected or under the pointer, leaving the title more room.
    static let minimumWidthForCloseButton: CGFloat = 100
    /// From a tab's top to the bottom of the tab bar, where the selected tab meets its terminal.
    static let height: CGFloat = 28
    /// Space between the window's top edge and the tabs.
    static let topInset: CGFloat = 4
    /// Space between the bar's edges and its first and last tabs.
    static let horizontalInset: CGFloat = 16
    /// Space between one tab group and the next.
    static let groupSpacing: CGFloat = 14
    static let cornerRadius: CGFloat = 8
    /// How far the selected tab's feet curve out past its sides at the bottom.
    static let footRadius: CGFloat = 6
}
