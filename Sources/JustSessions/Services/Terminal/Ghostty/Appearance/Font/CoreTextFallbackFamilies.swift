import AppKit
import CoreText

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
