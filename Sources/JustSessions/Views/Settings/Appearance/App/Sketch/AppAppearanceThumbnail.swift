import SwiftUI

/// The window sketch in one mode's colors. System shows the light and dark sketches side by side, split on a slant.
struct AppAppearanceThumbnail: View {
    let mode: AppAppearanceMode

    var body: some View {
        switch mode {
        case .system:
            AppWindowSketch()
                .environment(\.colorScheme, .light)
                .overlay {
                    AppWindowSketch()
                        .environment(\.colorScheme, .dark)
                        .mask(SlantedTrailingHalf())
                }
        case .light:
            AppWindowSketch().environment(\.colorScheme, .light)
        case .dark:
            AppWindowSketch().environment(\.colorScheme, .dark)
        }
    }
}

/// The part of a rectangle right of a line leaning from the bottom left to the top right through its center.
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
