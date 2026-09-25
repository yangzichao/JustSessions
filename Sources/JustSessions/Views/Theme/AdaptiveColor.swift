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

    /// Resolves to `lightColor` in Aqua and `darkColor` in Dark Aqua, following the view's appearance.
    static func adaptive(light lightColor: NSColor, dark darkColor: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }

    /// The concrete sRGB color this dynamic color draws as under `appearance`, for APIs that read components.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var resolvedColor = self
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = self.usingColorSpace(.sRGB) ?? self
        }
        return resolvedColor
    }
}

extension Color {
    /// A color that switches between two 0xRRGGBB values with the light or dark appearance.
    static func adaptive(light lightHexValue: UInt32, dark darkHexValue: UInt32) -> Color {
        Color(nsColor: .adaptive(light: NSColor(hexValue: lightHexValue), dark: NSColor(hexValue: darkHexValue)))
    }
}
