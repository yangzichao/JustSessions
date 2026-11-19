import AppKit
import CoreText
import GhosttyTerminal
import Testing

@testable import JustSessions

/// Ghostty draws the Nerd Font icons the terminal font lacks with the bundled symbols font, as SwiftTerm does, rather
/// than with a fallback family that has glyphs of its own at icons' codepoints: STIX Two Math's U+E0A0, Powerline's
/// branch icon, is a diagonal line, Hiragino Sans GB's U+E76C a euro sign, and Kefa's U+F506 a fraction.
@MainActor
@Suite(.serialized)
struct GhosttySymbolsFallbackTests {
    private static let symbolsFamily = TerminalSymbolsFont.familyName
    /// Powerline's branch icon, the Bulma Devicon, the relative-path Octicon, and the folder icon.
    private static let icons: [Unicode.Scalar] = ["\u{E0A0}", "\u{E76C}", "\u{F506}", "\u{F07B}"]
    /// Characters the symbols font has outside the Private Use Areas: power, menu, and heart symbols, and an angle
    /// bracket.
    private static let symbolsOutsideThePrivateUseAreas: [Unicode.Scalar] = ["\u{23FB}", "\u{23FE}", "\u{2630}", "\u{2665}", "\u{276F}"]
    /// See `TestMachine.isVirtual`.
    private static let drawnTextNeedsAMac: Comment = "Compares drawn text, which a virtual machine's GPU draws in other colors"

    /// Other characters keep the family that drew them before the symbols font joined the fallback families, as in
    /// SwiftTerm, which gives the symbols font only the Private Use Areas.
    @Test(arguments: [TerminalFontFamily.system, .named("Menlo"), .named("PT Mono")])
    func iconsTheFontLacksComeFromTheSymbolsFontAndOtherCharactersFromTheirFamilies(_ fontFamily: TerminalFontFamily) {
        let swiftTermFont = fontFamily.font(size: 13)
        let lines = Self.lines(of: TerminalAppearancePreferences(fontFamily: fontFamily))
        let families = GhosttyFontConfigurationTests.values(of: "font-family", in: lines)
        let codepointMaps = GhosttyFontConfigurationTests.values(of: "font-codepoint-map", in: lines)
        let familiesWithoutSymbols = [families[0]] + CoreTextFallbackFamilies.families(after: swiftTermFont)

        #expect(families.filter { $0 != Self.symbolsFamily } == familiesWithoutSymbols)
        for icon in Self.icons {
            #expect(
                Self.familyGhosttyDraws(icon, families: families, codepointMaps: codepointMaps) == Self.symbolsFamily, "U+\(Self.hex(icon))"
            )
        }
        for character in Self.symbolsOutsideThePrivateUseAreas {
            let familyBefore = Self.firstFamily(drawing: character, in: familiesWithoutSymbols) ?? Self.symbolsFamily
            #expect(
                Self.familyGhosttyDraws(character, families: families, codepointMaps: codepointMaps) == familyBefore,
                "U+\(Self.hex(character))")
        }
    }

    /// PT Mono has glyphs of its own at some Octicons' codepoints, which it keeps, as in SwiftTerm.
    @Test func iconsTheFontHasKeepItsGlyphs() {
        let lines = Self.lines(of: TerminalAppearancePreferences(fontFamily: .named("PT Mono")))
        let families = GhosttyFontConfigurationTests.values(of: "font-family", in: lines)
        let codepointMaps = GhosttyFontConfigurationTests.values(of: "font-codepoint-map", in: lines)

        #expect(Self.familyGhosttyDraws("\u{F401}", families: families, codepointMaps: codepointMaps) == "PT Mono")
    }

    /// The icons Ghostty draws, regular and bold, are the ones it draws with the symbols font as the only regular
    /// fallback family. Before, it drew U+E0A0 as STIX Two Math's diagonal line. Both keep the bold families, which
    /// Ghostty looks in first for bold text: a family without a face of the bold style's name can give it a face of
    /// another family, such as an installed Nerd Font's.
    @Test(.enabled(if: !TestMachine.isVirtual, Self.drawnTextNeedsAMac), arguments: [TerminalFontFamily.system, .named("Menlo")])
    func ghosttyDrawsTheIconsOfTheSymbolsFont(_ fontFamily: TerminalFontFamily) async throws {
        let output = "\u{1B}[?25l" + Self.icons.map { String($0) + " " }.joined() + "\u{1B}[1m\u{E0A0} \u{E76C}\u{1B}[0m"
        let configuration = GhosttyAppearanceConfiguration(
            preferences: TerminalAppearancePreferences(fontFamily: fontFamily), appTheme: ResolvedAppTheme(.justSessions)
        )
        let symbolsOnlyLines = Self.withOnlyTheSymbolsFontAsFallback(
            GhosttyAppearanceConfigurationTests.lines(of: configuration.terminalConfiguration))

        let drawn = try await Self.drawnPixels(of: output, configuration: configuration.terminalConfiguration, theme: configuration.theme)
        let drawnWithOnlySymbols = try await Self.drawnPixels(
            of: output, configuration: Self.configuration(symbolsOnlyLines), theme: configuration.theme)
        #expect(drawn == drawnWithOnlySymbols)
    }

    /// `lines` with the symbols font as the only regular fallback family and no `font-codepoint-map`.
    private static func withOnlyTheSymbolsFontAsFallback(_ lines: [String]) -> [String] {
        let familyKey = "font-family = "
        return lines.filter { !$0.hasPrefix("font-codepoint-map = ") }.reduce(into: [String]()) { kept, line in
            guard line.hasPrefix(familyKey) else {
                kept.append(line)
                return
            }
            guard !kept.contains(where: { $0.hasPrefix(familyKey) }) else { return }
            kept += [line, familyKey + symbolsFamily]
        }
    }

    /// The family Ghostty draws `character` with when the terminal font, the first of `families`, lacks it: the one a
    /// `font-codepoint-map` value gives it, or else the first of `families` that has it.
    private static func familyGhosttyDraws(_ character: Unicode.Scalar, families: [String], codepointMaps: [String]) -> String? {
        for codepointMap in codepointMaps {
            let parts = codepointMap.split(separator: "=", maxSplits: 1).map(String.init)
            let ranges = parts[0].split(separator: ",").map { range in
                let bounds = range.split(separator: "-").compactMap { UInt32($0.dropFirst(2), radix: 16) }
                return bounds[0]...bounds[bounds.count - 1]
            }
            if ranges.contains(where: { $0.contains(character.value) }) { return parts[1] }
        }
        return firstFamily(drawing: character, in: families)
    }

    private static func firstFamily(drawing character: Unicode.Scalar, in families: [String]) -> String? {
        families.first { family in
            let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
            return (CTFontCopyCharacterSet(CTFontCreateWithFontDescriptor(descriptor, 0, nil)) as CharacterSet).contains(character)
        }
    }

    private static func hex(_ character: Unicode.Scalar) -> String {
        String(format: "%04X", character.value)
    }

    private static func lines(of preferences: TerminalAppearancePreferences) -> [String] {
        let configuration = GhosttyAppearanceConfiguration(preferences: preferences, appTheme: ResolvedAppTheme(.justSessions))
        return GhosttyAppearanceConfigurationTests.lines(of: configuration.terminalConfiguration)
    }

    /// A configuration with the keys and values of `lines`, such as `font-size = 13`.
    private static func configuration(_ lines: [String]) -> TerminalConfiguration {
        TerminalConfiguration { builder in
            for line in lines {
                guard let separator = line.range(of: " = ") else { continue }
                builder.withCustom(String(line[..<separator.lowerBound]), String(line[separator.upperBound...]))
            }
        }
    }

    /// The pixels of a light terminal showing `output` on one line.
    private static func drawnPixels(of output: String, configuration: TerminalConfiguration, theme: TerminalTheme) async throws -> Data {
        let controller = TerminalController(
            configSource: .generated("# JustSessions test"), theme: theme, terminalConfiguration: configuration)
        let terminal = GhosttyTestTerminal(controller: controller, appearance: .aqua, frame: NSRect(x: 0, y: 0, width: 360, height: 60))
        #expect(controller.lastConfigurationIssue == nil)
        terminal.show(output)
        var bitmap: NSBitmapImageRep?
        try await expectEventually {
            bitmap = terminal.view.snapshotImage()?.representations.first as? NSBitmapImageRep
            return bitmap.map { DrawnTextLines($0).lines.count == 1 } ?? false
        }
        let drawnBitmap = try #require(bitmap)
        let pixels = try #require(drawnBitmap.bitmapData)
        return Data(bytes: pixels, count: drawnBitmap.bytesPerRow * drawnBitmap.pixelsHigh)
    }
}
