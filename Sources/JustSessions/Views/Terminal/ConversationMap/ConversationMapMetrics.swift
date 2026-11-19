import CoreGraphics

enum ConversationMapMetrics {
    @MainActor static var columnWidth: CGFloat { columnWidth(at: InterfaceScale.factor) }
    @MainActor static var naturalRowPitch: CGFloat { naturalRowPitch(at: InterfaceScale.factor) }
    @MainActor static var chipSide: CGFloat { chipSide(at: InterfaceScale.factor) }
    @MainActor static var minimumRowPitch: CGFloat { minimumRowPitch(at: InterfaceScale.factor) }
    static let verticalInset: CGFloat = 6
    static let leadingInset: CGFloat = 6
    static let chipGap: CGFloat = 3

    @MainActor static func columnWidth(at factor: CGFloat) -> CGFloat { InterfaceScale.points(110, at: factor) }
    @MainActor static func naturalRowPitch(at factor: CGFloat) -> CGFloat { InterfaceScale.points(3, at: factor) }
    @MainActor static func minimumRowPitch(at factor: CGFloat) -> CGFloat { InterfaceScale.points(1, at: factor) }
    @MainActor static func chipSide(at factor: CGFloat) -> CGFloat { InterfaceScale.points(14, at: factor) }
    @MainActor static func chipFontSize(at factor: CGFloat) -> CGFloat { InterfaceScale.points(10, at: factor) }
    @MainActor static func chipPadding(at factor: CGFloat) -> CGFloat { InterfaceScale.points(4, at: factor) }
    @MainActor static func labelChipMaximumWidth(at factor: CGFloat) -> CGFloat {
        columnWidth(at: factor) - leadingInset - chipGap - InterfaceScale.points(12, at: factor)
    }
    @MainActor static func scrollThumbWidth(at factor: CGFloat) -> CGFloat { InterfaceScale.points(2, at: factor) }
    @MainActor static func scrollThumbMinimumLength(at factor: CGFloat) -> CGFloat { InterfaceScale.points(16, at: factor) }
    static let wheelLineHeight: CGFloat = 16
}
