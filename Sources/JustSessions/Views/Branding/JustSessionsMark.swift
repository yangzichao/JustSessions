import AppKit
import SwiftUI

/// The app mark drawn natively: three comic speech bubbles stacked back to front in purple, orange, and white, each
/// outlined in ink. The front bubble holds one dot per CLI, in that CLI's tint. The colors stay the same in both
/// appearances: on a dark sidebar the ink outline reads as a gap between the bubbles.
/// Coordinates follow Branding/SVG/mark.svg.
struct JustSessionsMark: View {
    /// The stacked bubbles plus the outer half of their outline and a small margin, as in the SVG's viewBox.
    private static let designBounds = CGRect(x: -16, y: -16, width: 672, height: 580)
    private static let outlineWidth: CGFloat = 28
    private static let outlineColor = Color(nsColor: NSColor(hexValue: 0x15171C))
    private static let dotCenters = [CGPoint(x: 140, y: 276), CGPoint(x: 280, y: 276), CGPoint(x: 420, y: 276)]
    private static let dotRadius: CGFloat = 64

    /// Back to front, each bubble offset 40 down and to the left of the one behind it.
    private static let bubbleLayers = [
        BubbleLayer(outline: speechBubble.offsetBy(dx: 80, dy: 0), fillHexValue: 0xA64DF0),
        BubbleLayer(outline: speechBubble.offsetBy(dx: 40, dy: 40), fillHexValue: 0xFF8A1F),
        BubbleLayer(outline: speechBubble.offsetBy(dx: 0, dy: 80), fillHexValue: 0xFFFFFF),
    ]

    /// One bubble at the origin: the body and the tail joined into a single outline, so the stroke has no seam.
    private static let speechBubble: Path = {
        let body = Path(roundedRect: CGRect(x: 0, y: 0, width: 560, height: 392), cornerRadius: 120, style: .circular)
        var tail = Path()
        tail.move(to: CGPoint(x: 186, y: 370))
        tail.addLine(to: CGPoint(x: 186, y: 392))
        tail.addLine(to: CGPoint(x: 84, y: 466))
        tail.addQuadCurve(to: CGPoint(x: 68, y: 456), control: CGPoint(x: 72, y: 472))
        tail.addLine(to: CGPoint(x: 86, y: 387))
        tail.addLine(to: CGPoint(x: 86, y: 370))
        tail.closeSubpath()
        return body.union(tail)
    }()

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.designBounds.width, size.height / Self.designBounds.height)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Self.designBounds.minX, y: -Self.designBounds.minY)
            let outlineStyle = StrokeStyle(lineWidth: Self.outlineWidth, lineJoin: .round)
            for layer in Self.bubbleLayers {
                context.fill(layer.outline, with: .color(layer.fillColor))
                context.stroke(layer.outline, with: .color(Self.outlineColor), style: outlineStyle)
            }
            // The front bubble stays white in dark mode too, so the dots keep their light-appearance tints.
            for (provider, center) in zip(ConversationProvider.allCases, Self.dotCenters) {
                let dotBounds = CGRect(
                    x: center.x - Self.dotRadius,
                    y: center.y - Self.dotRadius,
                    width: 2 * Self.dotRadius,
                    height: 2 * Self.dotRadius
                )
                context.fill(Path(ellipseIn: dotBounds), with: .color(Color(nsColor: NSColor(hexValue: provider.tintHexColor.light))))
            }
        }
        .aspectRatio(Self.designBounds.size, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct BubbleLayer {
    let outline: Path
    let fillColor: Color

    init(outline: Path, fillHexValue: UInt32) {
        self.outline = outline
        fillColor = Color(nsColor: NSColor(hexValue: fillHexValue))
    }
}
