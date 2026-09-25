import SwiftUI

/// The app mark drawn natively: a speech bubble in the foreground color holding one dot per CLI, in that CLI's tint.
/// Coordinates follow Branding/SVG/mark.svg.
struct JustSessionsMark: View {
    private static let designSize = CGSize(width: 560, height: 467)
    private static let dotCenters = [CGPoint(x: 156, y: 196), CGPoint(x: 280, y: 196), CGPoint(x: 404, y: 196)]
    private static let dotRadius: CGFloat = 46

    private static let bubbleBody = Path(
        roundedRect: CGRect(x: 0, y: 0, width: 560, height: 392),
        cornerRadius: 120,
        style: .circular
    )

    /// Drawn separately from the body and overlapping it, so the two fills meet without a seam.
    private static let bubbleTail: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 186, y: 370))
        path.addLine(to: CGPoint(x: 186, y: 392))
        path.addLine(to: CGPoint(x: 84, y: 466))
        path.addQuadCurve(to: CGPoint(x: 68, y: 456), control: CGPoint(x: 72, y: 472))
        path.addLine(to: CGPoint(x: 86, y: 387))
        path.addLine(to: CGPoint(x: 86, y: 370))
        path.closeSubpath()
        return path
    }()

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.designSize.width, size.height / Self.designSize.height)
            context.scaleBy(x: scale, y: scale)
            context.fill(Self.bubbleBody, with: .foreground)
            context.fill(Self.bubbleTail, with: .foreground)
            for (provider, center) in zip(ConversationProvider.allCases, Self.dotCenters) {
                let dotBounds = CGRect(
                    x: center.x - Self.dotRadius,
                    y: center.y - Self.dotRadius,
                    width: 2 * Self.dotRadius,
                    height: 2 * Self.dotRadius
                )
                context.fill(Path(ellipseIn: dotBounds), with: .color(provider.tintColor))
            }
        }
        .aspectRatio(Self.designSize, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
