import AppKit
import CoreText

/// Draws the Nerd Font icons the terminal font lacks with the bundled symbols font, as SwiftTerm does; see
/// `TerminalSymbolsFont`. Ghostty takes a character the terminal font lacks from the first fallback family that has it,
/// and a few of the families from `CoreTextFallbackFamilies` have glyphs of their own at icons' codepoints: Hiragino
/// Sans GB draws some Devicons as letters, STIX Two Math draws U+E0A0, Powerline's branch icon, as a diagonal line, and
/// Kefa draws some Octicons as fractions. So the symbols font joins the fallback families just ahead of the first such
/// family, and the families before it keep every character they draw. Characters the terminal font has keep its
/// glyphs, and Ghostty still draws the Powerline separators itself, ahead of any font.
///
/// The symbols font also has a few characters outside the Private Use Areas, such as the power symbols from U+23FB,
/// which SwiftTerm draws with the system's usual fallback. Those that a family after the symbols font drew go back to
/// that family through `font-codepoint-map`, which Ghostty applies before looking in the fallback families.
@MainActor
struct GhosttySymbolsFallback {
    let fallbackFamilies: [String]
    let codepointMaps: [String]

    private static var fallbacksByKey: [String: GhosttySymbolsFallback] = [:]

    static func placing(in fallbackFamilies: [String], terminalFamily: String) -> GhosttySymbolsFallback {
        let key = ([terminalFamily] + fallbackFamilies).joined(separator: "\n")
        if let fallback = fallbacksByKey[key] { return fallback }
        let fallback = makeFallback(fallbackFamilies: fallbackFamilies, terminalFamily: terminalFamily)
        fallbacksByKey[key] = fallback
        return fallback
    }

    private static func makeFallback(fallbackFamilies: [String], terminalFamily: String) -> GhosttySymbolsFallback {
        guard TerminalSymbolsFont.isAvailableAfterRegisteringBundledCopy,
            let symbolsFont = NSFont(name: TerminalSymbolsFont.postScriptName, size: NSFont.systemFontSize)
        else {
            return GhosttySymbolsFallback(fallbackFamilies: fallbackFamilies, codepointMaps: [])
        }
        let charactersTheTerminalFontLacks = (CTFontCopyCharacterSet(symbolsFont) as CharacterSet)
            .subtracting(characters(ofFamily: terminalFamily))
        let iconsTheTerminalFontLacks = charactersTheTerminalFontLacks.intersection(TerminalSymbolsFont.privateUseAreas)
        let charactersOfFamilies = fallbackFamilies.map(characters(ofFamily:))
        let symbolsFontIndex = charactersOfFamilies.firstIndex { !$0.isDisjoint(with: iconsTheTerminalFontLacks) } ?? fallbackFamilies.count

        var codepointsByFamilyIndex: [Int: [UInt32]] = [:]
        for codepoint in codepoints(of: charactersTheTerminalFontLacks.subtracting(TerminalSymbolsFont.privateUseAreas)) {
            guard let character = Unicode.Scalar(codepoint),
                let familyIndex = charactersOfFamilies.firstIndex(where: { $0.contains(character) }),
                familyIndex >= symbolsFontIndex
            else { continue }
            codepointsByFamilyIndex[familyIndex, default: []].append(codepoint)
        }
        var families = fallbackFamilies
        families.insert(TerminalSymbolsFont.familyName, at: symbolsFontIndex)
        let codepointMaps = codepointsByFamilyIndex.keys.sorted().map { familyIndex in
            codepointRanges(codepointsByFamilyIndex[familyIndex] ?? []) + "=" + fallbackFamilies[familyIndex]
        }
        return GhosttySymbolsFallback(fallbackFamilies: families, codepointMaps: codepointMaps)
    }

    private static func characters(ofFamily family: String) -> CharacterSet {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        return CTFontCopyCharacterSet(CTFontCreateWithFontDescriptor(descriptor, 0, nil)) as CharacterSet
    }

    private static func codepoints(of characters: CharacterSet) -> [UInt32] {
        let planes = (0...16).filter { characters.hasMember(inPlane: UInt8($0)) }
        return planes.flatMap { plane in
            let planeStart = UInt32(plane) << 16
            return (planeStart...planeStart + 0xFFFF).filter { codepoint in
                Unicode.Scalar(codepoint).map { characters.contains($0) } ?? false
            }
        }
    }

    private static func codepointRanges(_ codepoints: [UInt32]) -> String {
        var ranges: [ClosedRange<UInt32>] = []
        for codepoint in codepoints {
            if let last = ranges.last, last.upperBound + 1 == codepoint {
                ranges[ranges.count - 1] = last.lowerBound...codepoint
            } else {
                ranges.append(codepoint...codepoint)
            }
        }
        return ranges.map { range in
            let start = String(format: "U+%04X", range.lowerBound)
            return range.count == 1 ? start : start + String(format: "-U+%04X", range.upperBound)
        }.joined(separator: ",")
    }
}
