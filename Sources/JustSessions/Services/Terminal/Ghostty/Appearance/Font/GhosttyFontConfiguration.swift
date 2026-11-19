import AppKit
import CoreText
import GhosttyTerminal

@MainActor
enum GhosttyFontConfiguration {
    static func add(
        to builder: inout TerminalConfiguration.Builder,
        preferences: TerminalAppearancePreferences,
        backingScaleFactor: CGFloat,
        ghosttyFindsFontFamily: (String) -> Bool
    ) {
        let size = CGFloat(preferences.fontSize)
        let swiftTermFont = preferences.fontFamily.font(size: size)
        let family = fontFamily(of: swiftTermFont, ghosttyFinds: ghosttyFindsFontFamily)
        builder.withFontFamily(family)
        builder.withFontSize(Float(size))
        addFallbackFamilies(to: &builder, family: family, after: swiftTermFont)
        if family == swiftTermFont.familyName {
            addStyleFaces(to: &builder, swiftTermFont: swiftTermFont)
        }
        addCellAdjustments(to: &builder, family: family, swiftTermFont: swiftTermFont, backingScaleFactor: backingScaleFactor)
        builder.withFontThicken(true)
    }

    /// How strongly Ghostty thickens text: as strongly as the smoothing of SwiftTerm, which draws in the text's color,
    /// thickens text of this color. Ghostty draws each glyph in a shade of gray this light and smooths it.
    static func thickenStrength(drawing foreground: UInt32) -> Int {
        let components = [16, 8, 0].map { CGFloat((foreground >> UInt32($0)) & 0xFF) / 255 }
        let color = NSColor(srgbRed: components[0], green: components[1], blue: components[2], alpha: 1)
        let gray = color.usingColorSpace(.deviceGray)?.whiteComponent ?? 1
        return Int((gray * 255).rounded())
    }

    static var screensBackingScaleFactor: CGFloat {
        NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
    }

    /// Characters the font lacks come from the families macOS would draw them with in SwiftTerm, at the font's size,
    /// and Nerd Font icons from the symbols font; see `GhosttySymbolsFallback`. Ghostty's own fallback scales a font to
    /// match the ideograph width it estimates for the terminal font, which draws Chinese larger than SwiftTerm does.
    /// Bold text gets them in bold, as in SwiftTerm. Italic text finds its missing characters in the regular ones, where
    /// Ghostty looks next: giving it its own would have Ghostty look up every family's italic faces too, which slowed
    /// opening the first Ghostty tab by a few tenths of a second.
    private static func addFallbackFamilies(to builder: inout TerminalConfiguration.Builder, family: String, after font: NSFont) {
        let symbolsFallback = GhosttySymbolsFallback.placing(in: CoreTextFallbackFamilies.families(after: font), terminalFamily: family)
        let fallbackFamilies = symbolsFallback.fallbackFamilies
        for fallbackFamily in fallbackFamilies {
            builder.withCustom("font-family", fallbackFamily)
        }
        for boldFamily in [family] + fallbackFamilies {
            builder.withCustom("font-family-bold", boldFamily)
        }
        builder.withCustom("font-family-italic", family)
        builder.withCustom("font-family-bold-italic", family)
        for codepointMap in symbolsFallback.codepointMaps {
            builder.withCustom("font-codepoint-map", codepointMap)
        }
    }

    private static func addStyleFaces(to builder: inout TerminalConfiguration.Builder, swiftTermFont: NSFont) {
        let styles: [(key: String, traits: NSFontTraitMask)] = [
            ("font-style-bold", .boldFontMask),
            ("font-style-italic", .italicFontMask),
            ("font-style-bold-italic", [.boldFontMask, .italicFontMask]),
        ]
        for (key, traits) in styles {
            let styledFont = NSFontManager.shared.convert(swiftTermFont, toHaveTrait: traits)
            guard let styleName = CTFontCopyAttribute(styledFont as CTFont, kCTFontStyleNameAttribute) as? String else { continue }
            builder.withCustom(key, styleName)
        }
    }

    private static func addCellAdjustments(
        to builder: inout TerminalConfiguration.Builder,
        family: String,
        swiftTermFont: NSFont,
        backingScaleFactor: CGFloat
    ) {
        let swiftTermCell = TerminalCellPixelSize.swiftTerm(font: swiftTermFont, backingScaleFactor: backingScaleFactor)
        let ghosttyCell = TerminalCellPixelSize.ghostty(
            family: family, pointSize: swiftTermFont.pointSize, backingScaleFactor: backingScaleFactor)
        if swiftTermCell.width != ghosttyCell.width {
            builder.withCustom("adjust-cell-width", String(swiftTermCell.width - ghosttyCell.width))
        }
        if swiftTermCell.height != ghosttyCell.height {
            builder.withCustom("adjust-cell-height", String(swiftTermCell.height - ghosttyCell.height))
        }
    }

    /// The family of the font a SwiftTerm terminal draws with. System Monospaced is SF Mono under its hidden family
    /// name, `.AppleSystemUIFontMonospaced`, which Ghostty's font discovery finds. A named family that is no longer
    /// installed gives the system font, as it does in SwiftTerm. A family Ghostty can't find gives Menlo, rather than
    /// Ghostty's built-in JetBrains Mono, whose cells are a different size.
    private static func fontFamily(of font: NSFont, ghosttyFinds: (String) -> Bool) -> String {
        let family = font.familyName ?? font.fontName
        guard !ghosttyFinds(family), ghosttyFinds(fallbackFontFamily) else { return family }
        return fallbackFontFamily
    }

    private static let fallbackFontFamily = "Menlo"

    /// Whether Ghostty's font discovery finds faces of `family`: it asks Core Text for a collection of the fonts whose
    /// family name is `family`.
    nonisolated static func fontDiscoveryFinds(family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let collection = CTFontCollectionCreateWithFontDescriptors([descriptor] as CFArray, nil)
        let matches = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        return !matches.isEmpty
    }
}
