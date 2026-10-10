import Foundation
import Testing
@testable import JustSessions

@MainActor
struct TerminalEngineStoreTests {
    @Test func tabsOpenWithSwiftTermUntilGhosttyIsChosen() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        #expect(TerminalEngineStore(userDefaults: settings.userDefaults).engine == .swiftTerm)
    }

    @Test(arguments: TerminalEngine.allCases)
    func theChosenEngineIsKeptForTheNextLaunch(_ engine: TerminalEngine) throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalEngineStore(userDefaults: settings.userDefaults)
        // Choosing the engine already in use saves nothing, so each case first chooses the other one.
        store.setEngine(TerminalEngine.allCases.first { $0 != engine }!)

        store.setEngine(engine)

        #expect(store.engine == engine)
        #expect(TerminalEngineStore(userDefaults: settings.userDefaults).engine == engine)
    }

    @Test func anEngineThisVersionDoesNotKnowFallsBackToSwiftTerm() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set("alacritty", forKey: TerminalEngineStore.userDefaultsKey)

        #expect(TerminalEngineStore(userDefaults: settings.userDefaults).engine == .swiftTerm)
    }

    @Test func restoringTheTerminalAppearanceDefaultsKeepsTheEngine() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        // The engine other than the default, so a reset would show.
        engineStore.setEngine(.ghostty)

        TerminalAppearanceStore(userDefaults: settings.userDefaults).restoreDefaults()

        #expect(TerminalEngineStore(userDefaults: settings.userDefaults).engine == .ghostty)
    }
}
