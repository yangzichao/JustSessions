import CoreText
import GhosttyTerminal
import Testing
@testable import JustSessions

/// The Ghostty configuration a controller from `GhosttyTerminalControllers` renders from the terminal appearance
/// settings. Ghostty rejects a whole configuration over one bad key or value, so each test checks it loaded.
@MainActor
@Suite(.serialized)
struct GhosttyAppearanceConfigurationTests {
    @Test func aNamedFontGivesItsFamilyAndSizeInPoints() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.appearance.setFontFamily(.named("Menlo"))
        stores.appearance.setFontSize(17.5)

        let controller = stores.controller()

        #expect(controller.lastConfigurationIssue == nil)
        #expect(Self.lines(of: controller).contains("font-family = Menlo"))
        #expect(Self.lines(of: controller).contains("font-size = 17.5"))
    }

    @Test func theSystemFontGivesSFMonoUnderTheFamilyNameGhosttyFinds() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }

        let controller = stores.controller()

        #expect(controller.lastConfigurationIssue == nil)
        #expect(Self.lines(of: controller).contains("font-family = .AppleSystemUIFontMonospaced"))
        #expect(Self.lines(of: controller).contains("font-size = 13"))
    }

    @Test func aFamilyNoLongerInstalledGivesTheSystemFontAsInSwiftTerm() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.appearance.setFontFamily(.named("No Such Font Family JustSessions"))

        let controller = stores.controller()

        #expect(controller.lastConfigurationIssue == nil)
        #expect(Self.lines(of: controller).contains("font-family = .AppleSystemUIFontMonospaced"))
    }

    /// Ghostty's font discovery asks Core Text for a collection of the fonts whose family name is the configured one.
    /// If it found none for System Monospaced, Ghostty would draw with its built-in JetBrains Mono.
    @Test func ghosttysFontDiscoveryFindsTheSystemFontsFamily() throws {
        let configuration = GhosttyAppearanceConfiguration(
            preferences: TerminalAppearancePreferences(), appTheme: ResolvedAppTheme(.justSessions), ghosttyFindsFontFamily: { _ in true }
        )
        let family = try #require(Self.lines(of: configuration.terminalConfiguration).first { $0.hasPrefix("font-family = ") })
            .dropFirst("font-family = ".count)

        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: String(family)] as CFDictionary)
        let collection = CTFontCollectionCreateWithFontDescriptors([descriptor] as CFArray, nil)
        let matches = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []

        #expect(!matches.isEmpty, "\(family)")
        #expect(GhosttyAppearanceConfiguration.fontDiscoveryFinds(family: String(family)))
        #expect(!GhosttyAppearanceConfiguration.fontDiscoveryFinds(family: "No Such Font Family JustSessions"))
    }

    @Test func aFamilyGhosttyCannotFindGivesMenloRatherThanGhosttysBuiltInFont() {
        let configuration = GhosttyAppearanceConfiguration(
            preferences: TerminalAppearancePreferences(), appTheme: ResolvedAppTheme(.justSessions), ghosttyFindsFontFamily: { $0 == "Menlo" }
        )

        #expect(Self.lines(of: configuration.terminalConfiguration).contains("font-family = Menlo"))
    }

    @Test func aSchemeWithOneVersionGivesTheSameColorsInLightAndDark() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.appearance.setMode(.light)
        stores.appearance.setColorChoice(.preset(.dracula))

        let controller = stores.controller()

        #expect(controller.theme.light == controller.theme.dark)
        Self.expectColors(of: TerminalPalette.dracula, in: controller)
        controller.setColorScheme(.dark)
        Self.expectColors(of: TerminalPalette.dracula, in: controller)
    }

    /// Tokyo Night Day's own selection colors are 3.3 apart, too little for selected text; see
    /// `TerminalColorScheme.readableSelectionForeground`.
    @Test func selectedTextTakesTheReadableSelectionColor() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.theme.setTheme(.tokyoNight)
        let scheme = AppThemeColors.tokyoNightDay.terminal
        try #require(scheme.readableSelectionForeground != scheme.selectionForeground)

        let controller = stores.controller()
        controller.setColorScheme(.light)

        #expect(Self.lines(of: controller).contains("selection-foreground = \(Self.hex(scheme.readableSelectionForeground))"))
        #expect(ThemeColorContrast.ratio(scheme.readableSelectionForeground, scheme.selectionBackground) >= 4.4)
    }

    @Test func aSchemeWithLightAndDarkVersionsGivesEachToItsColorScheme() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.theme.setTheme(.gruvbox)

        let controller = stores.controller()

        controller.setColorScheme(.light)
        Self.expectColors(of: AppThemeColors.gruvboxLight.terminalPalette, in: controller)
        controller.setColorScheme(.dark)
        Self.expectColors(of: AppThemeColors.gruvboxDark.terminalPalette, in: controller)
    }

    @Test func importedColorsAreUsed() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let palette = TerminalPalette(
            background: 0x0A0B0C,
            scheme: TerminalColorScheme(
                foreground: 0xF0E0D0,
                selectionBackground: 0x334455,
                selectionForeground: 0xFFFFFE,
                ansiHexColors: (0..<16).map { UInt32($0) * 0x0F0F0F }
            )
        )
        stores.appearance.useImportedColors(ImportedTerminalColors(sourceName: "Test", variants: .single(palette)))

        let controller = stores.controller()

        Self.expectColors(of: palette, in: controller)
        #expect(Self.lines(of: controller).contains("palette = 15=#E1E1E1"))
    }

    /// As in SwiftTerm, which ignores a set of other than 16 colors, such as one from damaged settings. Ghostty would
    /// reject the whole configuration over a color past 255.
    @Test func importedANSIColorsOfTheWrongCountAreIgnored() throws {
        for count in [8, 300] {
            let stores = try IsolatedAppearanceStores()
            defer { stores.remove() }
            let palette = TerminalPalette(
                background: 0x0A0B0C,
                scheme: TerminalColorScheme(
                    foreground: 0xF0E0D0,
                    selectionBackground: 0x334455,
                    selectionForeground: 0xFFFFFE,
                    ansiHexColors: (0..<count).map { UInt32($0) }
                )
            )
            stores.appearance.useImportedColors(ImportedTerminalColors(sourceName: "Test", variants: .single(palette)))

            let controller = stores.controller()

            #expect(controller.lastConfigurationIssue == nil, "\(count) colors")
            #expect(Self.lines(of: controller).contains("background = #0A0B0C"), "\(count) colors")
            #expect(!Self.lines(of: controller).contains { $0.hasPrefix("palette ") }, "\(count) colors")
        }
    }

    @Test func textIsKeptAsReadableAsInSwiftTerm() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }

        let controller = stores.controller()

        #expect(Self.lines(of: controller).contains("minimum-contrast = 4.5"))
    }

    /// Everything apart from the font and the colors, each set to behave as a SwiftTerm terminal does. Neither
    /// libghostty-spm's default configuration, which thickens the font, nor its default theme applies.
    @Test func theOtherKeysMatchSwiftTermsBehavior() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }

        let controller = stores.controller()

        #expect(controller.lastConfigurationIssue == nil)
        let lines = Self.lines(of: controller)
        let otherLines = lines.filter { line in
            !["#", "font-family ", "font-size ", "minimum-contrast ", "background ", "foreground ", "selection-",
              "cursor-color ", "cursor-text ", "palette "].contains { line.hasPrefix($0) }
        }
        #expect(otherLines == [
            "bold-color = bright",
            "window-padding-x = 0",
            "window-padding-y = 0",
            "cursor-style = block",
            "cursor-style-blink = true",
            "macos-option-as-alt = true",
            "clipboard-paste-protection = false",
            "clipboard-read = allow",
            "clipboard-write = allow",
            "keybind = clear",
            "keybind = super+arrow_left=esc:b",
            "keybind = super+arrow_right=esc:f",
            "keybind = alt+arrow_left=esc:b",
            "keybind = alt+arrow_right=esc:f",
            "keybind = super+backspace=ignore",
            "keybind = super+arrow_up=ignore",
            "keybind = super+arrow_down=ignore",
        ])
        #expect(!lines.contains { $0.hasPrefix("font-thicken") })
        // Alabaster, libghostty-spm's default light theme.
        #expect(!lines.contains("background = F7F7F7"))
    }

    @Test func everyColorChoiceLoadsInLightAndDark() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let controller = stores.controller()
        stores.appearance.useImportedColors(ImportedTerminalColors(sourceName: "Test", variants: .single(.nord)))
        let choices = [TerminalColorChoice.imported] + TerminalColorPreset.allCases.map(TerminalColorChoice.preset)

        for appTheme in AppTheme.allCases {
            stores.theme.setTheme(appTheme)
            for choice in [TerminalColorChoice.matchAppTheme] + choices {
                stores.appearance.setColorChoice(choice)
                let variants = stores.appearance.preferences.colorVariants(appTheme: ResolvedAppTheme(appTheme))
                for usesDarkColors in [false, true] {
                    controller.setColorScheme(usesDarkColors ? .dark : .light)
                    #expect(controller.lastConfigurationIssue == nil, "\(appTheme) \(choice) dark: \(usesDarkColors)")
                    Self.expectColors(of: variants.palette(usesDarkColors: usesDarkColors), in: controller)
                }
            }
        }
    }

    @Test func changingTheSettingsReconfiguresTheControllerLive() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let controller = stores.controller()
        controller.setColorScheme(.dark)

        stores.appearance.setFontFamily(.named("Menlo"))
        stores.appearance.setFontSize(20)
        stores.theme.setTheme(.tokyoNight)

        #expect(controller.lastConfigurationIssue == nil)
        #expect(Self.lines(of: controller).contains("font-family = Menlo"))
        #expect(Self.lines(of: controller).contains("font-size = 20"))
        Self.expectColors(of: AppThemeColors.tokyoNightNight.terminalPalette, in: controller)

        stores.appearance.setColorChoice(.preset(.nord))
        Self.expectColors(of: TerminalPalette.nord, in: controller)

        // The terminal view picks light or dark from the appearance this setting gives it, not the controller.
        let configuration = controller.renderedConfig
        stores.appearance.setMode(.light)
        #expect(controller.renderedConfig == configuration)
    }

    /// A theme color changed in Appearance settings reaches Ghostty's terminals once color picking pauses, as it
    /// reaches SwiftTerm's.
    @Test func aCustomizedThemeBackgroundReachesTheController() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults, terminalThemeDelay: .milliseconds(50))
        let controller = GhosttyTerminalControllers.shared.controller(appearanceStore: appearanceStore, themeStore: themeStore)
        // The dark version shows, as in a dark terminal.
        controller.setColorScheme(.dark)

        #expect(themeStore.setColor(0x000000, for: .contentSurface, isDark: true))

        try await expectEventually { Self.lines(of: controller).contains("background = #000000") }
        #expect(controller.lastConfigurationIssue == nil)
    }

    @Test func storesShareOneControllerAndOtherStoresGetTheirOwn() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let otherStores = try IsolatedAppearanceStores()
        defer { otherStores.remove() }
        let controllers = GhosttyTerminalControllers()

        let controller = controllers.controller(appearanceStore: stores.appearance, themeStore: stores.theme)

        #expect(controllers.controller(appearanceStore: stores.appearance, themeStore: stores.theme) === controller)
        #expect(controllers.controller(appearanceStore: otherStores.appearance, themeStore: otherStores.theme) !== controller)
        #expect(controllers.controller(appearanceStore: stores.appearance, themeStore: otherStores.theme) !== controller)
    }

    @Test func theControllerOfStoresThatAreGoneIsLetGo() throws {
        let controllers = GhosttyTerminalControllers()
        let otherStores = try IsolatedAppearanceStores()
        defer { otherStores.remove() }
        weak var goneAppearanceStore: TerminalAppearanceStore?
        weak var goneThemeStore: AppThemeStore?
        weak var controllerOfGoneStores: TerminalController?
        do {
            let stores = try IsolatedAppearanceStores()
            defer { stores.remove() }
            goneAppearanceStore = stores.appearance
            goneThemeStore = stores.theme
            controllerOfGoneStores = controllers.controller(appearanceStore: stores.appearance, themeStore: stores.theme)
        }
        #expect(goneAppearanceStore == nil && goneThemeStore == nil)
        #expect(controllerOfGoneStores != nil)

        _ = controllers.controller(appearanceStore: otherStores.appearance, themeStore: otherStores.theme)

        #expect(controllerOfGoneStores == nil)
    }

    static func lines(of controller: TerminalController) -> [String] {
        lines(of: controller.renderedConfig)
    }

    static func lines(of configuration: TerminalConfiguration) -> [String] {
        lines(of: configuration.rendered)
    }

    private static func lines(of renderedConfiguration: String) -> [String] {
        renderedConfiguration.split(separator: "\n").map(String.init)
    }

    static func expectColors(
        of palette: TerminalPalette,
        in controller: TerminalController,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let scheme = palette.scheme
        var expected = [
            "background = \(hex(palette.background))",
            "foreground = \(hex(scheme.foreground))",
            "selection-background = \(hex(scheme.selectionBackground))",
            "selection-foreground = \(hex(scheme.readableSelectionForeground))",
            "cursor-color = \(hex(scheme.foreground))",
            "cursor-text = \(hex(palette.background))",
        ]
        // The ANSI colors SwiftTerm draws with too, each kept apart from the background.
        expected += palette.distinguishableANSIHexColors.enumerated().map { "palette = \($0.offset)=\(hex($0.element))" }
        let lines = lines(of: controller)
        #expect(controller.lastConfigurationIssue == nil, sourceLocation: sourceLocation)
        #expect(expected.filter { !lines.contains($0) } == [], sourceLocation: sourceLocation)
    }

    static func hex(_ color: UInt32) -> String {
        String(format: "#%06X", color)
    }
}
