import CoreGraphics

@MainActor
enum ThemeSheetMetrics {
    nonisolated static let margin: CGFloat = 20
    nonisolated static let titleToIntroSpacing: CGFloat = 6
    nonisolated static let sectionSpacing: CGFloat = 16
    static var compactWidth: CGFloat { InterfaceScale.points(480) }
    static var regularWidth: CGFloat { InterfaceScale.points(520) }
    static var wideWidth: CGFloat { InterfaceScale.points(640) }
}
