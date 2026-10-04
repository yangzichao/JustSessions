import AppKit

/// Reads colors in iTerm2's format, shared by its profiles and .itermcolors files, into terminal palettes.
enum ITermColorsReader {
    static let lightSuffix = " (Light)"
    static let darkSuffix = " (Dark)"

    /// Reads one palette, or a light and a dark one when the colors are kept apart under " (Light)" and " (Dark)" keys.
    static func variants(from colors: [String: Any], usesSeparateLightAndDarkColors: Bool) throws -> TerminalPaletteVariants {
        guard usesSeparateLightAndDarkColors else { return .single(try palette(from: colors, keySuffix: "")) }
        return .lightAndDark(
            light: try palette(from: colors, keySuffix: lightSuffix),
            dark: try palette(from: colors, keySuffix: darkSuffix)
        )
    }

    private static func palette(from colors: [String: Any], keySuffix: String) throws -> TerminalPalette {
        func color(_ name: String) -> UInt32? { hexColor(from: colors[name + keySuffix]) }
        guard let background = color("Background Color"), let foreground = color("Foreground Color") else {
            throw TerminalColorsImportError.missingColors
        }
        // Some published presets leave out a color, so it borrows its normal or bright counterpart, as bright magenta
        // does in GitHub's own iTerm2 colors.
        let ansiHexColors = try (0..<16).map { index in
            guard let hexColor = color("Ansi \(index) Color") ?? color("Ansi \((index + 8) % 16) Color") else {
                throw TerminalColorsImportError.missingColors
            }
            return hexColor
        }
        return TerminalPalette(
            background: background,
            scheme: TerminalColorScheme(
                foreground: foreground,
                selectionBackground: color("Selection Color")
                    ?? ThemeColorContrast.blend(background, with: foreground, fraction: 0.3),
                selectionForeground: color("Selected Text Color") ?? foreground,
                ansiHexColors: ansiHexColors
            )
        )
    }

    /// Converts a color to sRGB the way iTerm2 reads it: sRGB and P3 as named, anything else as calibrated RGB.
    static func hexColor(from value: Any?) -> UInt32? {
        guard let dictionary = value as? [String: Any],
              let red = (dictionary["Red Component"] as? NSNumber)?.doubleValue,
              let green = (dictionary["Green Component"] as? NSNumber)?.doubleValue,
              let blue = (dictionary["Blue Component"] as? NSNumber)?.doubleValue else { return nil }
        let colorSpace: NSColorSpace = switch dictionary["Color Space"] as? String {
        case "sRGB": .sRGB
        case "P3": .displayP3
        default: .genericRGB
        }
        let components = [red, green, blue, 1].map { CGFloat($0) }
        guard let sRGBColor = NSColor(colorSpace: colorSpace, components: components, count: 4).usingColorSpace(.sRGB) else {
            return nil
        }
        return [sRGBColor.redComponent, sRGBColor.greenComponent, sRGBColor.blueComponent].reduce(0) { result, component in
            result << 8 | UInt32((min(max(component, 0), 1) * 255).rounded())
        }
    }
}
