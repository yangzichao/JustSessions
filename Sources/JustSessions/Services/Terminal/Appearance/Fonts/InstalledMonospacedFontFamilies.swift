import CoreText
import Foundation

struct InstalledMonospacedFontFamilies: Equatable {
    var fillingCells: [String]
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

    private static func lettersFillCells(_ family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        return FontFillsTerminalCells.check(CTFontCreateWithFontDescriptor(descriptor, 13, nil))
    }
}
