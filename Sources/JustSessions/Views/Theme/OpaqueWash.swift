import SwiftUI

/// One theme color washed over another at an opacity, drawn as a single opaque color. A window blends a translucent
/// fill in the display's color space, which on a P3 display came out lighter than the blend the theme checks text
/// against, and left a hovered group label below 4.5. This draws that blend exactly.
struct OpaqueWash: ShapeStyle {
    let surface: ThemeColor
    let wash: ThemeColor
    let opacity: Double

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let surfaceColor = surface.resolve(in: environment)
        let washColor = wash.resolve(in: environment)
        let fraction = Float(opacity)
        func blend(_ surfaceComponent: Float, _ washComponent: Float) -> Float {
            surfaceComponent + (washComponent - surfaceComponent) * fraction
        }
        return Color.Resolved(
            colorSpace: .sRGB,
            red: blend(surfaceColor.red, washColor.red),
            green: blend(surfaceColor.green, washColor.green),
            blue: blend(surfaceColor.blue, washColor.blue)
        )
    }
}
