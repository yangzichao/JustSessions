import CoreText
import Foundation

/// The installed font families with a monospaced face, split by whether their letters fill a terminal's cells. The font
/// picker offers the ones that do. Hidden system families, whose names start with a dot, and the symbols-only Nerd Font
/// families are left out. CoreText is thread-safe, and listing every font takes tens of milliseconds, so call `load()`
/// away from the main thread.
struct InstalledMonospacedFontFamilies: Equatable {
    /// Sorted.
    var fillingCells: [String]
    /// Such as Osaka; see `FontFillsTerminalCells`.
    var notFillingCells: Set<String>

    static func load() -> Self {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        let families = Set(descriptors.filter(isMonospaced).compactMap(familyName))
            .filter { !$0.hasPrefix(".") && !TerminalSymbolsFont.familyNames.contains($0) }
        let fillingCells = families.filter(lettersFillCells)
        return Self(
            fillingCells: fillingCells.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            notFillingCells: families.subtracting(fillingCells)
        )
    }

    private static func isMonospaced(_ descriptor: CTFontDescriptor) -> Bool {
        guard let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any],
            let symbolicTraits = traits[kCTFontSymbolicTrait] as? UInt32
        else { return false }
        return CTFontSymbolicTraits(rawValue: symbolicTraits).contains(.traitMonoSpace)
    }

    private static func familyName(_ descriptor: CTFontDescriptor) -> String? {
        CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
    }

    /// Checked on the face Core Text picks for the family, its regular one. Widths scale together, so any size will do.
    private static func lettersFillCells(_ family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        return FontFillsTerminalCells.check(CTFontCreateWithFontDescriptor(descriptor, 13, nil))
    }
}
