import AppKit
import SwiftUI

extension NSColor {
    convenience init(hexValue: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: alpha
        )
    }

    var sRGBHexValue: UInt32? {
        guard let sRGBColor = usingColorSpace(.sRGB) else { return nil }
        return [sRGBColor.redComponent, sRGBColor.greenComponent, sRGBColor.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((min(max(component, 0), 1) * 255).rounded())
        }
    }

    static func adaptive(light lightColor: NSColor, dark darkColor: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }
}

extension Color {
    static func adaptive(light lightHexValue: UInt32, dark darkHexValue: UInt32) -> Color {
        Color(nsColor: .adaptive(light: NSColor(hexValue: lightHexValue), dark: NSColor(hexValue: darkHexValue)))
    }

    static func adaptive(_ hexColor: AdaptiveHexColor) -> Color {
        adaptive(light: hexColor.light, dark: hexColor.dark)
    }
}
