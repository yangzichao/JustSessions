import Foundation

enum ThemeColorContrast {
    /// WCAG's minimum for body text.
    static let minimumTextRatio = 4.5

    /// The color, darkened on light surfaces or lightened on dark ones just enough to stay readable on every surface,
    /// so it keeps as much of its hue as it can.
    static func readableText(_ text: UInt32, on surfaces: [UInt32]) -> UInt32 {
        let contrastTarget: UInt32 = isDark(surfaces[0]) ? 0xFFFFFF : 0x000000
        for step in 0...100 {
            let foreground = blend(text, with: contrastTarget, fraction: Double(step) / 100)
            if surfaces.allSatisfy({ ratio(foreground, $0) >= minimumTextRatio }) { return foreground }
        }
        return contrastTarget
    }

    /// Keeps the hue as close to the theme as possible while making the small group label readable when hovered, on
    /// each surface the label sits on.
    static func readableAccent(_ accent: UInt32, on surfaces: [UInt32]) -> UInt32 {
        let contrastTarget: UInt32 = isDark(surfaces[0]) ? 0xFFFFFF : 0x000000
        for step in 0...100 {
            let foreground = blend(accent, with: contrastTarget, fraction: Double(step) / 100)
            let isReadable = surfaces.allSatisfy { surface in
                ratio(foreground, blend(surface, with: foreground, fraction: 0.24)) >= minimumTextRatio
            }
            if isReadable { return foreground }
        }
        return contrastTarget
    }

    /// The color, lightened on a dark surface or darkened on a light one just enough to stand apart from the surface
    /// as a fill, by `minimumRatio`. A color already that far apart is unchanged.
    static func distinguishableFill(_ fill: UInt32, on surface: UInt32, minimumRatio: Double) -> UInt32 {
        guard ratio(fill, surface) < minimumRatio else { return fill }
        let contrastTarget: UInt32 = isDark(surface) ? 0xFFFFFF : 0x000000
        for step in 1...100 {
            let candidate = blend(fill, with: contrastTarget, fraction: Double(step) / 100)
            if ratio(candidate, surface) >= minimumRatio { return candidate }
        }
        return contrastTarget
    }

    /// Whether white text reads better than black on the surface.
    static func isDark(_ surface: UInt32) -> Bool {
        ratio(0xFFFFFF, surface) > ratio(0x000000, surface)
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
