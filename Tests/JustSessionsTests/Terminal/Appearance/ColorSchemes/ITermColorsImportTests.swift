import Foundation
import Testing
@testable import JustSessions

struct ITermColorsImportTests {
    @Test func readsTheDefaultProfileByItsGuid() throws {
        let otherProfile = profile(guid: "other", name: "Other", background: 0x111111)
        let defaultProfile = profile(guid: "default", name: "Work", background: 0x222222)

        let imported = try ITermProfileColorsImporter.importDefaultProfile(
            defaultProfileGuid: "default", profiles: [otherProfile, defaultProfile]
        )

        #expect(imported.sourceName == "iTerm2 · Work")
        let palette = imported.variants.palette(usesDarkColors: false)
        #expect(palette == imported.variants.palette(usesDarkColors: true))
        #expect(palette.background == 0x222222)
        #expect(palette.scheme.foreground == 0xEEEEEE)
        #expect(palette.scheme.selectionBackground == 0x334455)
        #expect(palette.scheme.selectionForeground == 0xFFFFFF)
        #expect(palette.scheme.ansiHexColors == Self.ansiHexColors)
    }

    @Test func aProfileWithSeparateLightAndDarkColorsKeepsBoth() throws {
        var defaultProfile: [String: Any] = ["Guid": "default", "Name": "Work", "Use Separate Colors for Light and Dark Mode": true]
        defaultProfile.merge(colors(background: 0xFAFAFA, foreground: 0x222222, keySuffix: " (Light)")) { $1 }
        defaultProfile.merge(colors(background: 0x101010, foreground: 0xEEEEEE, keySuffix: " (Dark)")) { $1 }

        let variants = try ITermProfileColorsImporter.importDefaultProfile(defaultProfileGuid: "default", profiles: [defaultProfile]).variants

        #expect(variants.hasLightAndDarkVersions)
        #expect(variants.palette(usesDarkColors: false).background == 0xFAFAFA)
        #expect(variants.palette(usesDarkColors: true).background == 0x101010)
    }

    @Test func missingSettingsAProfileOrAColorIsReported() {
        #expect(throws: TerminalColorsImportError.iTermSettingsNotFound) {
            try ITermProfileColorsImporter.importDefaultProfile(defaultProfileGuid: nil, profiles: nil)
        }
        #expect(throws: TerminalColorsImportError.iTermDefaultProfileNotFound) {
            try ITermProfileColorsImporter.importDefaultProfile(defaultProfileGuid: "dynamic", profiles: [profile(guid: "other")])
        }
        for missingColors in [["Background Color"], ["Ansi 7 Color", "Ansi 15 Color"]] {
            var incomplete = profile(guid: "default")
            for key in missingColors { incomplete[key] = nil }
            #expect(throws: TerminalColorsImportError.missingColors, "\(missingColors)") {
                try ITermProfileColorsImporter.importDefaultProfile(defaultProfileGuid: "default", profiles: [incomplete])
            }
        }
    }

    @Test func aMissingANSIColorBorrowsItsNormalOrBrightCounterpart() throws {
        var colors = colors(background: 0x000000, foreground: 0xFFFFFF)
        colors["Ansi 13 Color"] = nil
        colors["Ansi 2 Color"] = nil

        let ansiHexColors = try ITermColorsReader.variants(from: colors, usesSeparateLightAndDarkColors: false)
            .palette(usesDarkColors: true).scheme.ansiHexColors

        #expect(ansiHexColors[13] == Self.ansiHexColors[5])
        #expect(ansiHexColors[2] == Self.ansiHexColors[10])
    }

    @Test func missingSelectionColorsFallBackToTheTextAndBackground() throws {
        var colors = colors(background: 0x000000, foreground: 0xFFFFFF)
        colors["Selection Color"] = nil
        colors["Selected Text Color"] = nil

        let scheme = try ITermColorsReader.variants(from: colors, usesSeparateLightAndDarkColors: false)
            .palette(usesDarkColors: true).scheme

        #expect(scheme.selectionBackground == ThemeColorContrast.blend(0x000000, with: 0xFFFFFF, fraction: 0.3))
        #expect(scheme.selectionForeground == 0xFFFFFF)
    }

    @Test func calibratedColorsAndColorsWithoutASpaceAreConvertedToSRGBLikeITerm2() {
        // Nord's background in its .itermcolors file, which is #2E3440 once converted.
        var nordBackground: [String: Any] = [
            "Red Component": 0.1357133686542511, "Green Component": 0.15255947411060333,
            "Blue Component": 0.19183900952339172, "Color Space": "Calibrated",
        ]
        #expect(ITermColorsReader.hexColor(from: nordBackground) == 0x2E3440)
        nordBackground["Color Space"] = nil
        #expect(ITermColorsReader.hexColor(from: nordBackground) == 0x2E3440)
        #expect(ITermColorsReader.hexColor(from: colorDictionary(0x8BE9FD)) == 0x8BE9FD)
        #expect(ITermColorsReader.hexColor(from: ["Red Component": 1]) == nil)
    }

    @Test func importsAColorPresetFileNamedAfterTheFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let presetURL = directory.appendingPathComponent("Night Owl.itermcolors")
        try PropertyListSerialization.data(fromPropertyList: colors(background: 0x011627, foreground: 0xD6DEEB), format: .xml, options: 0)
            .write(to: presetURL)

        let imported = try ITermColorsFileImporter.importFile(at: presetURL)

        #expect(imported.sourceName == "Night Owl")
        #expect(imported.variants == .single(imported.variants.palette(usesDarkColors: true)))
        #expect(imported.variants.palette(usesDarkColors: true).background == 0x011627)

        let notAPresetURL = directory.appendingPathComponent("notes.itermcolors")
        try Data("not a property list".utf8).write(to: notAPresetURL)
        #expect(throws: TerminalColorsImportError.unreadableFile) { try ITermColorsFileImporter.importFile(at: notAPresetURL) }
    }

    @Test func aColorPresetFileWithOnlyLightAndDarkColorsKeepsBoth() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var presetColors = colors(background: 0xFFFFFF, foreground: 0x111111, keySuffix: " (Light)")
        presetColors.merge(colors(background: 0x111111, foreground: 0xFFFFFF, keySuffix: " (Dark)")) { $1 }
        let presetURL = directory.appendingPathComponent("Both.itermcolors")
        try PropertyListSerialization.data(fromPropertyList: presetColors, format: .xml, options: 0).write(to: presetURL)

        let variants = try ITermColorsFileImporter.importFile(at: presetURL).variants

        #expect(variants.palette(usesDarkColors: false).background == 0xFFFFFF)
        #expect(variants.palette(usesDarkColors: true).background == 0x111111)
    }

    private static let ansiHexColors: [UInt32] = [
        0x000000, 0xAA0000, 0x00AA00, 0xAA5500, 0x0000AA, 0xAA00AA, 0x00AAAA, 0xAAAAAA,
        0x555555, 0xFF5555, 0x55FF55, 0xFFFF55, 0x5555FF, 0xFF55FF, 0x55FFFF, 0xFFFFFF,
    ]

    private func profile(guid: String, name: String = "Profile", background: UInt32 = 0x000000) -> [String: Any] {
        var profile: [String: Any] = ["Guid": guid, "Name": name]
        profile.merge(colors(background: background, foreground: 0xEEEEEE)) { $1 }
        return profile
    }

    private func colors(background: UInt32, foreground: UInt32, keySuffix: String = "") -> [String: Any] {
        var colors: [String: Any] = [
            "Background Color" + keySuffix: colorDictionary(background),
            "Foreground Color" + keySuffix: colorDictionary(foreground),
            "Selection Color" + keySuffix: colorDictionary(0x334455),
            "Selected Text Color" + keySuffix: colorDictionary(0xFFFFFF),
        ]
        for (index, hexColor) in Self.ansiHexColors.enumerated() {
            colors["Ansi \(index) Color" + keySuffix] = colorDictionary(hexColor)
        }
        return colors
    }

    private func colorDictionary(_ hexColor: UInt32) -> [String: Any] {
        [
            "Red Component": Double((hexColor >> 16) & 0xFF) / 255,
            "Green Component": Double((hexColor >> 8) & 0xFF) / 255,
            "Blue Component": Double(hexColor & 0xFF) / 255,
            "Alpha Component": 1.0,
            "Color Space": "sRGB",
        ]
    }
}
