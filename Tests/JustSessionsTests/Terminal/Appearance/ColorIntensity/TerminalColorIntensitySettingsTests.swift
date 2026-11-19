import Foundation
import Testing

@testable import JustSessions

/// **Color intensity** is saved with the other terminal settings, and dragging it recolors terminals once it pauses.
@MainActor
struct TerminalColorIntensitySettingsTests {
    @Test func intensitySurvivesReopeningAndRestoreDefaultsResetsIt() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setColorIntensityPercent(150)

        let reopened = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        #expect(reopened.preferences.colorIntensityPercent == 150)
        #expect(reopened.terminalPreferences.colorIntensityPercent == 150)

        reopened.restoreDefaults()
        #expect(reopened.preferences == TerminalAppearancePreferences())
        #expect(reopened.terminalPreferences == TerminalAppearancePreferences())
        #expect(TerminalAppearancePreferences.load(from: settings.userDefaults).colorIntensityPercent == 100)
    }

    @Test func aSavedIntensityOutOfRangeIsClampedAndAMissingOneIsTheDefault() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let key = TerminalAppearancePreferences.userDefaultsKey
        let savedSettings = [
            #"{"colorIntensityPercent":500}"#: 200,
            #"{"colorIntensityPercent":-20}"#: 50,
            #"{"colorIntensityPercent":"vivid","mode":"dark"}"#: 100,
            #"{"mode":"dark"}"#: 100,
        ]
        for (saved, expectedPercent) in savedSettings {
            settings.userDefaults.set(Data(saved.utf8), forKey: key)
            #expect(TerminalAppearancePreferences.load(from: settings.userDefaults).colorIntensityPercent == expectedPercent, "\(saved)")
        }
    }

    @Test func terminalsTakeANewIntensityOnceDraggingPauses() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults, terminalPreferencesDelay: .milliseconds(100))
        var terminalIntensities: [Int] = []
        let subscription = store.$terminalPreferences.dropFirst().sink { terminalIntensities.append($0.colorIntensityPercent) }
        defer { subscription.cancel() }

        // A drag along the slider.
        for percent in [110, 125, 140] {
            store.setColorIntensityPercent(percent)
        }
        #expect(store.preferences.colorIntensityPercent == 140)
        #expect(store.terminalPreferences.colorIntensityPercent == 100)

        try await expectEventually { store.terminalPreferences.colorIntensityPercent == 140 }
        #expect(terminalIntensities == [140])
    }

    /// Another setting reaches terminals at once, and takes an intensity still waiting along with it.
    @Test func anotherSettingReachesTerminalsAtOnceWithAWaitingIntensity() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults, terminalPreferencesDelay: .seconds(60))
        store.setColorIntensityPercent(170)
        #expect(store.terminalPreferences.colorIntensityPercent == 100)

        store.setFontSize(18)

        #expect(store.terminalPreferences.fontSize == 18)
        #expect(store.terminalPreferences.colorIntensityPercent == 170)
    }
}
