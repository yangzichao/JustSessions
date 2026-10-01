import Foundation

enum ThemeColorContrast {
    /// Secondary text keeps the theme's ink hue while remaining readable on both flat and raised surfaces.
    static func readableText(_ text: UInt32, on surfaces: [UInt32]) -> UInt32 {
        let contrastTarget: UInt32 = ratio(0x000000, surfaces[0]) > ratio(0xFFFFFF, surfaces[0]) ? 0x000000 : 0xFFFFFF
        for step in 0...100 {
            let foreground = blend(text, with: contrastTarget, fraction: Double(step) / 100)
            if surfaces.allSatisfy({ ratio(foreground, $0) >= 4.5 }) { return foreground }
        }
        return contrastTarget
    }

    /// Keeps the hue as close to the theme as possible while making the small group label readable when hovered.
    static func readableAccent(_ accent: UInt32, on surface: UInt32) -> UInt32 {
        let contrastTarget: UInt32 = ratio(0x000000, surface) > ratio(0xFFFFFF, surface) ? 0x000000 : 0xFFFFFF
        for step in 0...100 {
            let foreground = blend(accent, with: contrastTarget, fraction: Double(step) / 100)
            let labelBackground = blend(surface, with: foreground, fraction: 0.24)
            if ratio(foreground, labelBackground) >= 4.5 { return foreground }
        }
        return contrastTarget
    }

    static func blend(_ first: UInt32, with second: UInt32, fraction: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { result, shift in
            let firstChannel = Double((first >> shift) & 0xFF)
            let secondChannel = Double((second >> shift) & 0xFF)
            let blendedChannel = UInt32((firstChannel + (secondChannel - firstChannel) * fraction).rounded())
            return result << 8 | blendedChannel
        }
    }

    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private static func relativeLuminance(_ hexValue: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift -> Double in
            let encoded = Double((hexValue >> shift) & 0xFF) / 255
            return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
