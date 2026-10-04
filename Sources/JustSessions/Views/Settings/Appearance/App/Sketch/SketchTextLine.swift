import SwiftUI

/// A line of text in a window sketch, drawn as a bar.
struct SketchTextLine<Style: ShapeStyle>: View {
    let width: CGFloat
    var height: CGFloat = 2
    let style: Style

    var body: some View {
        Capsule()
            .fill(style)
            .frame(width: width, height: height)
    }
}
