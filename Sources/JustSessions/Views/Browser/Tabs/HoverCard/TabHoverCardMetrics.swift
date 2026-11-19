import CoreGraphics

enum TabHoverCardMetrics {
    @MainActor static var width: CGFloat { InterfaceScale.points(280) }
    static let gapBelowTab: CGFloat = 4
    static let windowMargin: CGFloat = 8
    static let cornerRadius = ThemeCornerRadius.card.rawValue
    static let slideDuration: Double = 0.2
}
