import AppKit
import CoreText
import Foundation
import Testing

@testable import JustSessions

@MainActor
struct TerminalFontFamilyTests {
    /// A Powerline separator, a folder icon, and a Material Design icon from the supplementary Private Use Area.
    private static let icons = "\u{E0B0}\u{F07B}\u{F0001}"

    /// The PostScript names of the fonts CoreText draws `text` with, run by run.
    private static func drawingFonts(of text: String, in font: NSFont) -> Set<String> {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        return Set(
            (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).compactMap { run in
                ((CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName]).map { CTFontCopyPostScriptName($0 as! CTFont) as String }
            })
    }

    @Test func savedFamiliesLoadIncludingTheThreeEarlierChoices() throws {
        let decoder = JSONDecoder()
        func decoded(_ value: String) throws -> TerminalFontFamily {
            try decoder.decode(TerminalFontFamily.self, from: JSONEncoder().encode(value))
        }

        #expect(try decoded("system") == .system)
        #expect(try decoded("  ") == .system)
        #expect(try decoded("menlo") == .named("Menlo"))
        #expect(try decoded("monaco") == .named("Monaco"))
        for family in [TerminalFontFamily.system, .named("JetBrainsMono Nerd Font Mono")] {
            #expect(try decoder.decode(TerminalFontFamily.self, from: JSONEncoder().encode(family)) == family)
        }
    }

    @Test func aFamilyGivesItsRegularFaceAndAMissingOneTheSystemFont() {
        let systemFamily = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).familyName

        #expect(TerminalFontFamily.named("Menlo").font(size: 13).fontName == "Menlo-Regular")
        #expect(TerminalFontFamily.named("Monaco").font(size: 13).fontName == "Monaco")
        #expect(TerminalFontFamily.named("No Such Font Family").font(size: 13) == NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        #expect(TerminalFontFamily.system.font(size: 13).familyName == systemFamily)
        // Equal fonts let a terminal skip reassigning an unchanged font, which would clear its selection.
        #expect(TerminalFontFamily.named("Menlo").font(size: 13) == TerminalFontFamily.named("Menlo").font(size: 13))
    }

    /// The app ships the symbols font, so icons draw on Macs without a Nerd Font installed, in regular and bold text.
    /// Letters keep the chosen font, and symbols outside the Private Use Areas keep the system's usual fallback.
    @Test(arguments: [TerminalFontFamily.named("Menlo"), .named("Monaco")])
    func nerdFontIconsDrawWithTheBundledSymbolsWithAnyFont(_ family: TerminalFontFamily) throws {
        let bundledFont = try #require(
            AppLocalization.resourceBundle.url(
                forResource: "SymbolsNerdFontMono-Regular", withExtension: "ttf", subdirectory: "Fonts"
            ))
        let bundledDescriptors = CTFontManagerCreateFontDescriptorsFromURL(bundledFont as CFURL) as? [CTFontDescriptor] ?? []
        #expect(
            bundledDescriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String } == [
                TerminalSymbolsFont.postScriptName
            ])

        let font = family.font(size: 13)
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)

        #expect(Self.drawingFonts(of: Self.icons, in: font) == [TerminalSymbolsFont.postScriptName])
        #expect(Self.drawingFonts(of: Self.icons, in: bold) == [TerminalSymbolsFont.postScriptName])
        #expect(Self.drawingFonts(of: "ls -la", in: font) == [font.fontName])
        #expect(!Self.drawingFonts(of: "\u{23FB}", in: font).contains(TerminalSymbolsFont.postScriptName))
    }

    /// macOS ignores fallback fonts for its system fonts, so System Monospaced stays exactly the system's font, as
    /// Settings says. Which icons it draws depends on the Nerd Fonts installed on the Mac, so this checks none: macOS's
    /// own fallback never uses the font the app registers. On a Mac without Nerd Fonts, as on the release runner, it
    /// drew a supplementary-area icon as the LastResort placeholder.
    @Test func systemMonospacedIsExactlyTheSystemFont() {
        let font = TerminalFontFamily.system.font(size: 13)

        #expect(font == NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        #expect(font.fontDescriptor.object(forKey: .cascadeList) == nil)
    }

    /// Hiragino Sans's and Helvetica's letters have different widths, as Osaka's and Lantinghei TC's.
    @Test func lettersFillTheCellsOnlyInFontsWhoseLettersAreAllAsWideAsW() throws {
        for family in ["Menlo", "Monaco", "Courier New", "PT Mono"] {
            let font = try #require(NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: 13))
            #expect(FontFillsTerminalCells.check(font as CTFont), "\(family)")
        }
        for family in ["Hiragino Sans", "Helvetica", "Apple Color Emoji"] {
            let font = try #require(NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: 13))
            #expect(!FontFillsTerminalCells.check(font as CTFont), "\(family)")
        }
    }

    /// BIZ UDGothic names no glyph W, but its W, which the cells are as wide as, is as wide as its other letters.
    @Test(.enabled(if: BIZUDGothicFont.isInstalled, BIZUDGothicFont.needsTheFont))
    func lettersFillTheCellsInAFontThatNamesNoGlyphW() throws {
        let font = try #require(NSFontManager.shared.font(withFamily: BIZUDGothicFont.family, traits: [], weight: 5, size: 13))

        #expect(CTFontGetGlyphWithName(font, "W" as CFString) == 0)
        #expect(FontFillsTerminalCells.check(font as CTFont))
        #expect(TerminalFontFamily.named(BIZUDGothicFont.family).font(size: 13).familyName == BIZUDGothicFont.family)
    }

    @Test func aFamilyWhoseLettersDontFillTheCellsGivesTheSystemFont() throws {
        try #require(NSFontManager.shared.font(withFamily: "Hiragino Sans", traits: [], weight: 5, size: 13) != nil)

        #expect(TerminalFontFamily.named("Hiragino Sans").font(size: 13) == NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
    }

    @Test func installedFamiliesAreTheMonospacedOnesWithLettersThatFillTheCells() {
        TerminalSymbolsFont.register()
        let families = InstalledMonospacedFontFamilies.load()

        #expect(families.fillingCells.contains("Menlo"))
        #expect(families.fillingCells.contains("Monaco"))
        #expect(!families.fillingCells.contains("Helvetica"))
        #expect(!families.notFillingCells.contains("Helvetica"))
        #expect(families.notFillingCells.isDisjoint(with: families.fillingCells))
        for family in families.fillingCells {
            #expect(FontFillsTerminalCells.check(Self.regularFace(of: family)), "\(family)")
        }
        for family in families.notFillingCells {
            #expect(!FontFillsTerminalCells.check(Self.regularFace(of: family)), "\(family)")
        }
        let allFamilies = families.fillingCells + families.notFillingCells
        #expect(allFamilies.allSatisfy { !$0.hasPrefix(".") && !TerminalSymbolsFont.familyNames.contains($0) })
        #expect(families.fillingCells == families.fillingCells.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    private static func regularFace(of family: String) -> CTFont {
        CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary), 13, nil)
    }

    @Test func thePickerAlwaysListsTheChosenFamilyAndMarksOneItDoesntOffer() {
        typealias Choice = TerminalFontPicker.Choice
        let installed = InstalledMonospacedFontFamilies(fillingCells: ["Menlo", "Monaco"], notFillingCells: ["Osaka"])

        #expect(
            TerminalFontPicker.choices(installed: installed, chosen: .named("Menlo"))
                == [Choice(family: "Menlo", unavailability: nil), Choice(family: "Monaco", unavailability: nil)])
        #expect(
            TerminalFontPicker.choices(installed: installed, chosen: .named("Hack"))
                == [
                    Choice(family: "Hack", unavailability: .notInstalled), Choice(family: "Menlo", unavailability: nil),
                    Choice(family: "Monaco", unavailability: nil),
                ])
        #expect(
            TerminalFontPicker.choices(installed: installed, chosen: .named("Osaka"))
                == [
                    Choice(family: "Menlo", unavailability: nil), Choice(family: "Monaco", unavailability: nil),
                    Choice(family: "Osaka", unavailability: .notFillingCells),
                ])
        #expect(TerminalFontPicker.choices(installed: nil, chosen: .named("Hack")) == [Choice(family: "Hack", unavailability: nil)])
        #expect(TerminalFontPicker.choices(installed: nil, chosen: .system).isEmpty)
    }
}
