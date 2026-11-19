import AppKit
import CoreText

/// The font families macOS draws a font's missing characters with, in the order it tries them, for the preferred
/// languages: what SwiftTerm draws Chinese, Japanese, and other characters outside the terminal font with. Families
/// Ghostty's font discovery doesn't find by name are left out. Looking each one up takes a moment, so the families
/// are kept for each font family and language list.
@MainActor
enum CoreTextFallbackFamilies {
    private static var familiesByKey: [String: [String]] = [:]

    static func families(after font: NSFont) -> [String] {
        let languages = Locale.preferredLanguages
        let primaryFamily = font.familyName ?? font.fontName
        let key = ([primaryFamily] + languages).joined(separator: "\n")
        if let families = familiesByKey[key] { return families }
        let cascade = CTFontCopyDefaultCascadeListForLanguages(font as CTFont, languages as CFArray) as? [CTFontDescriptor] ?? []
        var families: [String] = []
        for descriptor in cascade {
            guard let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
                family != primaryFamily, !families.contains(family),
                GhosttyFontConfiguration.fontDiscoveryFinds(family: family)
            else { continue }
            families.append(family)
        }
        familiesByKey[key] = families
        return families
    }
}
