import SwiftUI

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
