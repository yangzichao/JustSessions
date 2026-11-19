import AppKit
import CoreText
import GhosttyTerminal
import Testing

@testable import JustSessions

/// The font keys that make Ghostty draw text as SwiftTerm does. `GhosttyTextMatchesSwiftTermTests` compares the drawn
/// text.
@MainActor
@Suite(.serialized)
struct GhosttyFontConfigurationTests {
    /// SwiftTerm draws a Chinese character the terminal font lacks with the font macOS picks for it. Ghostty finds it
    /// among the configured families rather than looking one up and scaling it. The symbols font joins them for Nerd
    /// Font icons; see `GhosttySymbolsFallbackTests`.
    @Test func missingCharactersComeFromTheFamiliesMacOSDrawsThemWith() throws {
        let font = TerminalFontFamily.system.font(size: 13)
        let lines = Self.lines(of: TerminalAppearancePreferences())

        let families = Self.values(of: "font-family", in: lines)

        #expect(families.first == ".AppleSystemUIFontMonospaced")
        #expect(families.contains(TerminalSymbolsFont.familyName))
        #expect(families.dropFirst().filter { $0 != TerminalSymbolsFont.familyName } == CoreTextFallbackFamilies.families(after: font))
        #expect(families.dropFirst().contains { Self.family($0, draws: "中") })
    }

    /// Italic text finds its missing characters among the regular ones.
    @Test func boldTextFindsMissingCharactersInBoldAndItalicTextInTheRegularFamilies() {
        let lines = Self.lines(of: TerminalAppearancePreferences(fontFamily: .named("Menlo")))
        let families = Self.values(of: "font-family", in: lines)

        #expect(families.first == "Menlo")
        #expect(Self.values(of: "font-family-bold", in: lines) == families)
        #expect(Self.values(of: "font-family-italic", in: lines) == ["Menlo"])
        #expect(Self.values(of: "font-family-bold-italic", in: lines) == ["Menlo"])
    }

    /// The faces `NSFontManager` gives SwiftTerm. Monaco has no bold or italic face, and PT Mono no italic one.
    @Test(arguments: [
        (TerminalFontFamily.system, ["Semibold", "Regular Italic", "Semibold Italic"]),
        (.named("Menlo"), ["Bold", "Italic", "Bold Italic"]),
        (.named("Monaco"), ["Regular", "Regular", "Regular"]),
        (.named("PT Mono"), ["Bold", "Regular", "Regular"]),
    ])
    func boldAndItalicTextTakeTheFacesSwiftTermDrawsItWith(_ family: TerminalFontFamily, _ styles: [String]) {
        let lines = Self.lines(of: TerminalAppearancePreferences(fontFamily: family))

        #expect(Self.values(of: "font-style-bold", in: lines) == [styles[0]])
        #expect(Self.values(of: "font-style-italic", in: lines) == [styles[1]])
        #expect(Self.values(of: "font-style-bold-italic", in: lines) == [styles[2]])
    }

    /// SwiftTerm smooths light text on a dark background more than dark text on a light one.
    @Test func darkColorsThickenTextMoreThanLightColors() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }

        let controller = stores.controller()
        controller.setColorScheme(.light)
        let lightLines = GhosttyAppearanceConfigurationTests.lines(of: controller)
        controller.setColorScheme(.dark)
        let darkLines = GhosttyAppearanceConfigurationTests.lines(of: controller)

        #expect(controller.lastConfigurationIssue == nil)
        #expect(lightLines.contains("font-thicken = true"))
        let lightStrength = try #require(Self.values(of: "font-thicken-strength", in: lightLines).last.flatMap { Int($0) })
        let darkStrength = try #require(Self.values(of: "font-thicken-strength", in: darkLines).last.flatMap { Int($0) })
        #expect(lightStrength < 64)
        #expect(darkStrength > 192)
    }

    @Test func blackTextIsNotThickenedAndWhiteTextFully() {
        #expect(GhosttyFontConfiguration.thickenStrength(drawing: 0x000000) == 0)
        #expect(GhosttyFontConfiguration.thickenStrength(drawing: 0xFFFFFF) == 255)
    }

    /// SF Mono's cells are as wide and a pixel shorter in Ghostty at 13 points on a Retina screen.
    @Test func cellsAreAdjustedByTheDifferenceFromSwiftTerms() {
        let lines = Self.lines(of: TerminalAppearancePreferences(), backingScaleFactor: 2)

        #expect(
            TerminalCellPixelSize.swiftTerm(font: TerminalFontFamily.system.font(size: 13), backingScaleFactor: 2)
                == TerminalCellPixelSize(width: 16, height: 32))
        #expect(!lines.contains { $0.hasPrefix("adjust-cell-width") })
        #expect(lines.contains("adjust-cell-height = 1"))
    }

    private static func lines(of preferences: TerminalAppearancePreferences, backingScaleFactor: CGFloat = 2) -> [String] {
        let configuration = GhosttyAppearanceConfiguration(
            preferences: preferences, appTheme: ResolvedAppTheme(.justSessions), backingScaleFactor: backingScaleFactor
        )
        return GhosttyAppearanceConfigurationTests.lines(of: configuration.terminalConfiguration)
    }

    private static func family(_ family: String, draws character: Character) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, 13, nil)
        var characters = Array(character.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
    }

    static func values(of key: String, in lines: [String]) -> [String] {
        lines.compactMap { line in line.hasPrefix("\(key) = ") ? String(line.dropFirst("\(key) = ".count)) : nil }
    }
}
