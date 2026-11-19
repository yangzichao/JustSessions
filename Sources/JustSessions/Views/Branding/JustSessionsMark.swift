import AppKit
import SwiftUI

struct JustSessionsMark: View {
    private static let designBounds = CGRect(x: -16, y: -16, width: 672, height: 580)
    private static let outlineWidth: CGFloat = 28
    private static let outlineColor = Color(nsColor: NSColor(hexValue: 0x15171C))
    private static let dotCenters = [CGPoint(x: 140, y: 276), CGPoint(x: 280, y: 276), CGPoint(x: 420, y: 276)]
    private static let dotRadius: CGFloat = 64

    private static let bubbleLayers = [
        BubbleLayer(outline: speechBubble.offsetBy(dx: 80, dy: 0), fillHexValue: 0xA64DF0),
        BubbleLayer(outline: speechBubble.offsetBy(dx: 40, dy: 40), fillHexValue: 0xFF8A1F),
        BubbleLayer(outline: speechBubble.offsetBy(dx: 0, dy: 80), fillHexValue: 0xFFFFFF),
    ]

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
