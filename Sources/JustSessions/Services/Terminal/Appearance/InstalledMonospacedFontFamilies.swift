import CoreText
import Foundation

/// The installed font families with a monospaced face, which the terminal font picker offers. Hidden system families,
/// whose names start with a dot, and the symbols-only Nerd Font families are left out. CoreText is thread-safe, and
/// listing every font takes tens of milliseconds, so call this away from the main thread.
enum InstalledMonospacedFontFamilies {
    static func load() -> [String] {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        let families = Set(descriptors.filter(isMonospaced).compactMap(familyName))
        return families
            .filter { !$0.hasPrefix(".") && !TerminalSymbolsFont.familyNames.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func isMonospaced(_ descriptor: CTFontDescriptor) -> Bool {
        guard let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any],
              let symbolicTraits = traits[kCTFontSymbolicTrait] as? UInt32 else { return false }
        return CTFontSymbolicTraits(rawValue: symbolicTraits).contains(.traitMonoSpace)
    }

    private static func familyName(_ descriptor: CTFontDescriptor) -> String? {
        CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
    }
}
