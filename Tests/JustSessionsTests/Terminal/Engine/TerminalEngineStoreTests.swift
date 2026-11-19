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
        engineStore.setEngine(.ghostty)

        TerminalAppearanceStore(userDefaults: settings.userDefaults).restoreDefaults()

        #expect(TerminalEngineStore(userDefaults: settings.userDefaults).engine == .ghostty)
    }
}
