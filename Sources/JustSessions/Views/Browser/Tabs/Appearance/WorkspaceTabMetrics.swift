import CoreGraphics

@MainActor
enum WorkspaceTabMetrics {
    static var maximumWidth: CGFloat { InterfaceScale.points(200) }
    static var minimumWidth: CGFloat { InterfaceScale.points(72) }
    static var minimumSplitTabWidth: CGFloat { InterfaceScale.points(56) }
    static var minimumWidthForCloseButton: CGFloat { InterfaceScale.points(100) }
    nonisolated static let height: CGFloat = 28
    nonisolated static let topInset: CGFloat = 4
    nonisolated static let horizontalInset: CGFloat = 16
    nonisolated static let groupSpacing: CGFloat = 14
    nonisolated static let cornerRadius = ThemeCornerRadius.card.rawValue
    nonisolated static let footRadius: CGFloat = 6
    nonisolated static let groupLineWidth: CGFloat = 2
}
