import AppKit
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

    @Test func changingTheBackgroundChangesOnlyThatVersionAndTheTerminalsBackground() throws {
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

    @Test func aChangedTextColorIsMadeReadableAndHairlinesFollowIt() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        // Far too pale to read on the light version's paper.
        let paleBlue: UInt32 = 0x9AB8FF

        #expect(store.setColor(paleBlue, for: .ink, isDark: false))

        let light = store.resolvedTheme.colors(isDark: false)
        #expect(light.seeds.ink == paleBlue)
        #expect(light.ink != paleBlue)
        #expect(light.line == paleBlue)
        #expect(light.suits(isDark: false))
        for surface in light.textSurfaces {
            #expect(ThemeColorContrast.ratio(light.ink, surface) >= 4.5)
            #expect(ThemeColorContrast.ratio(light.tertiaryText, surface) >= 4.5)
        }
        #expect(ThemeColorContrast.ratio(light.inkForeground, light.ink) >= 4.5)
    }

    @Test func aSurfaceTextCantStayReadableOnIsRefused() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)

        // A light background in the dark version.
        #expect(!store.setColor(0xF0F0F0, for: .contentSurface, isDark: true))
        // A gray light enough for the light version, but dark text under the pointer's hover fill falls below 4.5.
        #expect(!ThemeColorContrast.isDark(0x777777))
        #expect(!store.setColor(0x777777, for: .sidebarSurface, isDark: false))

        #expect(store.resolvedTheme.customization.isEmpty)
        #expect(settings.userDefaults.data(forKey: AppThemeCustomization.userDefaultsKey) == nil)
    }

    @Test func choosingTheThemesOwnColorRemovesTheChange() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = AppThemeStore(userDefaults: settings.userDefaults)
        store.setColor(0xFFFFFF, for: .sidebarSurface, isDark: false)
        #expect(!store.resolvedTheme.customization.isEmpty)

        store.setColor(AppThemeColors.justSessionsLight.sidebarSurface, for: .sidebarSurface, isDark: false)

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
        #expect(AppThemeStore(userDefaults: settings.userDefaults).resolvedTheme.customization.isEmpty)
    }

    @Test func savedChangesThisVersionCantUseAreLeftOut() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let saved = """
        {
          "solarized": {"dark": {"contentSurface": 1052688}},
          "nord": {"light": {"contentSurface": 16777215}},
          "gitHub": {
            "light": {"accentColor": 255, "sidebarSurface": 16448250},
            "dark": {"contentSurface": 16777215}
          }
        }
        """
        settings.userDefaults.set(Data(saved.utf8), forKey: AppThemeCustomization.userDefaultsKey)

        let customizations = AppThemeCustomization.loadAll(from: settings.userDefaults)

        #expect(Array(customizations.keys) == [.gitHub])
        // An unknown color is left out; a white background no longer suits the dark version.
        #expect(customizations[.gitHub]?.lightChanges == [.sidebarSurface: 0xFAFAFA])
        #expect(customizations[.gitHub]?.darkChanges.isEmpty == true)
    }

    @Test func terminalsMatchingTheAppThemeTakeAChangedBackground() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let terminalStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        terminalStore.setMode(.dark)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: terminalStore, themeStore: themeStore
        )

        themeStore.setColor(0x000000, for: .contentSurface, isDark: true)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: 0x000000))

        terminalStore.setColorChoice(.preset(.justSessions))
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: AppThemeColors.justSessionsDark.contentSurface))
    }
}
