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
        return Set((CTLineGetGlyphRuns(line) as? [CTRun] ?? []).compactMap { run in
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
        let bundledFont = try #require(AppLocalization.resourceBundle.url(
            forResource: "SymbolsNerdFontMono-Regular", withExtension: "ttf", subdirectory: "Fonts"
        ))
        let bundledDescriptors = CTFontManagerCreateFontDescriptorsFromURL(bundledFont as CFURL) as? [CTFontDescriptor] ?? []
        #expect(bundledDescriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String } == [TerminalSymbolsFont.postScriptName])

        let font = family.font(size: 13)
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)

        #expect(Self.drawingFonts(of: Self.icons, in: font) == [TerminalSymbolsFont.postScriptName])
        #expect(Self.drawingFonts(of: Self.icons, in: bold) == [TerminalSymbolsFont.postScriptName])
        #expect(Self.drawingFonts(of: "ls -la", in: font) == [font.fontName])
        #expect(!Self.drawingFonts(of: "\u{23FB}", in: font).contains(TerminalSymbolsFont.postScriptName))
    }

    /// macOS ignores fallback fonts for its system fonts, so System Monospaced stays exactly the system's font. Its own
    /// fallback still finds an icon font for the supplementary Private Use Areas, as Settings says: the registered
    /// symbols font, or a Nerd Font installed on the Mac, rather than its LastResort placeholder.
    @Test func systemMonospacedIsTheSystemFontAndShowsSomeIcons() {
        let font = TerminalFontFamily.system.font(size: 13)

        #expect(font == NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        #expect(font.fontDescriptor.object(forKey: .cascadeList) == nil)
        #expect(!Self.drawingFonts(of: "\u{F0001}", in: font).contains("LastResort"))
    }

    @Test func installedFamiliesAreTheMonospacedOnesWithLetters() {
        TerminalSymbolsFont.register()
        let families = InstalledMonospacedFontFamilies.load()

        #expect(families.contains("Menlo"))
        #expect(families.contains("Monaco"))
        #expect(!families.contains("Helvetica"))
        #expect(families.allSatisfy { !$0.hasPrefix(".") && !TerminalSymbolsFont.familyNames.contains($0) })
        #expect(families == families.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func thePickerAlwaysListsTheChosenFamilyAndMarksOneThatIsGone() {
        typealias Choice = TerminalFontPicker.Choice

        #expect(TerminalFontPicker.choices(installed: ["Menlo", "Monaco"], chosen: .named("Menlo"))
            == [Choice(family: "Menlo", isMissing: false), Choice(family: "Monaco", isMissing: false)])
        #expect(TerminalFontPicker.choices(installed: ["Menlo", "Monaco"], chosen: .named("Hack"))
            == [Choice(family: "Hack", isMissing: true), Choice(family: "Menlo", isMissing: false), Choice(family: "Monaco", isMissing: false)])
        #expect(TerminalFontPicker.choices(installed: nil, chosen: .named("Hack")) == [Choice(family: "Hack", isMissing: false)])
        #expect(TerminalFontPicker.choices(installed: nil, chosen: .system).isEmpty)
    }
}
