import AppKit
import Combine
import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AppThemeCustomizationTests {
    @Test func aThemeWithoutChangesDrawsItsOwnColors() {
        for theme in AppTheme.allCases {
            for isDark in [false, true] {
                #expect(ResolvedAppTheme(theme).colors(isDark: isDark) == theme.colors(isDark: isDark), "\(theme) \(isDark)")
            }
        }
    }

    @Test func changingTheBackgroundChangesOnlyThatVersion() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        store.setTheme(.catppuccin)

        #expect(store.setColor(0x101018, for: .contentSurface, isDark: true))

        let dark = store.resolvedTheme.colors(isDark: true)
        #expect(dark.contentSurface == 0x101018)
        #expect(dark.terminalPalette.background == 0x101018)
        #expect(dark.sidebarSurface == AppThemeColors.catppuccinMocha.sidebarSurface)
        #expect(dark.terminal.ansiHexColors == AppThemeColors.catppuccinMocha.terminal.ansiHexColors)
        #expect(store.resolvedTheme.colors(isDark: false) == AppThemeColors.catppuccinLatte)
    }

    @Test func aPaleTextColorIsDrawnReadableAndHairlinesFollowWhatIsDrawn() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        // Far too pale to read on the light version's paper.
        let paleBlue: UInt32 = 0xE0E8FF

        #expect(store.setColor(paleBlue, for: .ink, isDark: false))

        let light = store.resolvedTheme.colors(isDark: false)
        #expect(store.resolvedTheme.customization.lightChanges == [.ink: paleBlue])
        #expect(light.ink != paleBlue)
        #expect(light.line == light.seeds.ink)
        #expect(ThemeColorContrast.ratio(light.line, light.contentSurface) >= 4.5)
        #expect(keepsTextReadable(light))
    }

    @Test func aSurfaceTextCantStayReadableOnIsRefused() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)

        // A light background in the dark version.
        #expect(!store.setColor(0xF0F0F0, for: .contentSurface, isDark: true))
        // Light enough for the light version, but under a selected row's wash dark text falls below 4.5.
        #expect(!ThemeColorContrast.isDark(0x808080))
        #expect(!store.setColor(0x808080, for: .sidebarSurface, isDark: false))

        #expect(store.resolvedTheme.customization.isEmpty)
        #expect(settings.userDefaults.data(forKey: AppThemeCustomization.userDefaultsKey) == nil)
    }

    @Test func anyTextColorAndGoingBackToTheThemesOwnColorAreTaken() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        #expect(store.setColor(0xA8A8A8, for: .sidebarSurface, isDark: false))

        for ink: UInt32 in [0x000000, 0x333333, 0xFFFFFF, 0xFF8A1F] {
            #expect(store.setColor(ink, for: .ink, isDark: false), "\(String(ink, radix: 16))")
            #expect(keepsTextReadable(store.resolvedTheme.colors(isDark: false)))
        }
        #expect(store.setColor(nil, for: .ink, isDark: false))
        #expect(store.setColor(nil, for: .sidebarSurface, isDark: false))
        #expect(store.resolvedTheme.customization.isEmpty)
    }

    @Test func everyCombinationOfTakenColorsKeepsTextReadable() {
        var random = SeededRandomNumberGenerator(seed: 116)
        var takenCount = 0
        for _ in 0..<400 {
            let theme = AppTheme.allCases.randomElement(using: &random)!
            let isDark = Bool.random(using: &random)
            let themeSeeds = theme.colors(isDark: isDark).seeds
            var changes: [CustomizableThemeColor: UInt32] = [:]
            for color in CustomizableThemeColor.allCases where Bool.random(using: &random) {
                let candidate = changes.merging([color: UInt32.random(in: 0...0xFFFFFF, using: &random)]) { $1 }
                if themeSeeds.applying(candidate).surfacesSuit(isDark: isDark) { changes = candidate }
            }
            guard !changes.isEmpty else { continue }
            takenCount += 1
            let colors = theme.colors(isDark: isDark).applying(changes)
            #expect(keepsTextReadable(colors), "\(theme) dark=\(isDark) \(changes)")
            #expect(ThemeColorContrast.ratio(colors.terminal.foreground, colors.contentSurface) >= 4.5)
        }
        #expect(takenCount > 100)
    }

    @Test func choosingTheThemesOwnColorRemovesTheChange() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        store.setColor(0xFFFFFF, for: .sidebarSurface, isDark: false)
        #expect(!store.resolvedTheme.customization.isEmpty)

        store.setColor(AppThemeColors.justSessionsLight.sidebarSurface, for: .sidebarSurface, isDark: false)
        #expect(store.resolvedTheme.customization.isEmpty)

        // Tokyo Night Day's ink is drawn darker than the theme's own blue; either one is the theme's own.
        store.setTheme(.tokyoNight)
        store.setColor(AppThemeColors.tokyoNightDay.ink, for: .ink, isDark: false)
        store.setColor(AppThemeColors.tokyoNightDay.seeds.ink, for: .ink, isDark: false)
        #expect(store.resolvedTheme.customization.isEmpty)
    }

    @Test func changesStayWithTheirThemeAndSurviveReopening() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        store.setTheme(.gruvbox)
        store.setColor(0x111111, for: .contentSurface, isDark: true)
        store.setColor(0xFFFDF5, for: .userMessageSurface, isDark: false)

        store.setTheme(.tokyoNight)
        #expect(store.resolvedTheme == ResolvedAppTheme(.tokyoNight))
        #expect(store.resolvedTheme(for: .gruvbox).colors(isDark: true).contentSurface == 0x111111)

        let reopened = AppThemeStore(userDefaults: settings.userDefaults)
        reopened.setTheme(.gruvbox)
        #expect(reopened.resolvedTheme.colors(isDark: true).contentSurface == 0x111111)
        #expect(reopened.resolvedTheme.colors(isDark: false).userMessageSurface == 0xFFFDF5)
        #expect(reopened.resolvedTheme == store.resolvedTheme(for: .gruvbox))
    }

    @Test func resetGivesTheChosenThemeBackAllItsOwnColors() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        store.setColor(0x0A0A0A, for: .contentSurface, isDark: true)
        store.setColor(0x2F6BFF, for: .ink, isDark: false)

        store.removeCustomization()

        #expect(store.resolvedTheme == ResolvedAppTheme(.justSessions))
        #expect(store.terminalTheme == ResolvedAppTheme(.justSessions))
        #expect(AppThemeStore(userDefaults: settings.userDefaults).resolvedTheme.customization.isEmpty)
    }

    @Test func savedValuesThisVersionCantUseLeaveOutOnlyThemselves() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let saved = """
        {
          "version": 2,
          "solarized": {"dark": {"contentSurface": 1052688}},
          "gitHub": {
            "light": {
              "accentColor": 255, "sidebarSurface": 16448250, "raisedSurface": "white",
              "userMessageSurface": -1, "ink": 1.5, "contentSurface": 33554431
            },
            "dark": {"contentSurface": 16777215}
          },
          "gruvbox": {"dark": {"contentSurface": 1118481}, "light": [1, 2]}
        }
        """
        settings.userDefaults.set(Data(saved.utf8), forKey: AppThemeCustomization.userDefaultsKey)

        let customizations = AppThemeCustomization.loadAll(from: settings.userDefaults)

        #expect(Set(customizations.keys) == [.gitHub, .gruvbox])
        #expect(customizations[.gitHub]?.lightChanges == [.sidebarSurface: 0xFAFAFA])
        // A white background no longer suits the dark version.
        #expect(customizations[.gitHub]?.darkChanges.isEmpty == true)
        #expect(customizations[.gruvbox]?.darkChanges == [.contentSurface: 0x111111])
    }

    @Test func aChangedBackgroundKeepsTheTerminalSelectionVisible() {
        // JustSessions dark's own selection color.
        let background: UInt32 = 0x3C4B62
        let colors = AppThemeColors.justSessionsDark.applying([.contentSurface: background])

        #expect(AppThemeColors.justSessionsDark.terminal.selectionBackground == background)
        #expect(ThemeColorContrast.ratio(colors.terminal.selectionBackground, background) >= AppThemeSeeds.minimumSelectionContrast)
        // A background the selection still stands out from keeps the theme's selection.
        #expect(AppThemeColors.justSessionsDark.applying([.contentSurface: 0x000000]).terminal.selectionBackground == background)
    }

    @Test func terminalsTakeAChangedBackgroundOnceColorPickingPauses() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let terminalStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults, terminalThemeDelay: .milliseconds(100))
        terminalStore.setMode(.dark)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: terminalStore, themeStore: themeStore
        )
        var terminalThemes: [ResolvedAppTheme] = []
        let subscription = themeStore.$terminalTheme.dropFirst().sink { terminalThemes.append($0) }
        defer { subscription.cancel() }

        // A drag across the color panel.
        for background: UInt32 in [0x101010, 0x080808, 0x000000] {
            themeStore.setColor(background, for: .contentSurface, isDark: true)
        }
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.contentSurface))

        try await expectEventually { terminalView.nativeBackgroundColor == NSColor(hexValue: 0x000000) }
        #expect(terminalThemes == [themeStore.resolvedTheme])

        terminalStore.setColorChoice(.preset(.justSessions))
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.contentSurface))
    }

    /// Every text color reads at 4.5 on every surface it sits on, and on the ink.
    private func keepsTextReadable(_ colors: AppThemeColors) -> Bool {
        let textColors = [colors.ink, colors.secondaryText, colors.tertiaryText, colors.warningText, colors.errorText]
            + colors.providerTextHexColors.values
        let textIsReadable = textColors.allSatisfy { textColor in
            colors.textSurfaces.allSatisfy { ThemeColorContrast.ratio(textColor, $0) >= 4.5 }
        }
        return textIsReadable && ThemeColorContrast.ratio(colors.inkForeground, colors.ink) >= 4.5
    }
}
