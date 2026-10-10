import CoreGraphics

/// Sizes of the tab bar's hover card.
enum TabHoverCardMetrics {
    /// One width for every card, as Chrome's are, so a card moving from tab to tab keeps its shape.
    static let width: CGFloat = 280
    /// Space between the bottom of the tab bar and the card.
    static let gapBelowTab: CGFloat = 4
    /// The card keeps this far inside the window's edges.
    static let windowMargin: CGFloat = 8
    static let cornerRadius: CGFloat = 8
    /// As Chrome's hover card slides from one tab to the next, `kHoverCardSlideDuration`.
    static let slideDuration: Double = 0.2
}
