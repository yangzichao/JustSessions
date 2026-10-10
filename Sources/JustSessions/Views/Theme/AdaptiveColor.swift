import AppKit
import SwiftUI

extension NSColor {
    /// A color from a 0xRRGGBB value, such as `0x15171C`.
    convenience init(hexValue: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// The color as a 0xRRGGBB value in sRGB, or nil when it can't be converted, such as a pattern.
    var sRGBHexValue: UInt32? {
        guard let sRGBColor = usingColorSpace(.sRGB) else { return nil }
        return [sRGBColor.redComponent, sRGBColor.greenComponent, sRGBColor.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((min(max(component, 0), 1) * 255).rounded())
        }
    }

    /// Resolves to `lightColor` in Aqua and `darkColor` in Dark Aqua, following the view's appearance.
    static func adaptive(light lightColor: NSColor, dark darkColor: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }
}

extension Color {
    /// A color that switches between two 0xRRGGBB values with the light or dark appearance.
    static func adaptive(light lightHexValue: UInt32, dark darkHexValue: UInt32) -> Color {
        Color(nsColor: .adaptive(light: NSColor(hexValue: lightHexValue), dark: NSColor(hexValue: darkHexValue)))
    }

    static func adaptive(_ hexColor: AdaptiveHexColor) -> Color {
        adaptive(light: hexColor.light, dark: hexColor.dark)
    }
}
