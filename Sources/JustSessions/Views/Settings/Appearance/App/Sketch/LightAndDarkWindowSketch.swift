import SwiftUI

struct LightAndDarkWindowSketch: View {
    var body: some View {
        AppWindowSketch()
            .environment(\.colorScheme, .light)
            .overlay {
                AppWindowSketch()
                    .environment(\.colorScheme, .dark)
                    .mask(SlantedTrailingHalf())
            }
    }
}

private struct SlantedTrailingHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
