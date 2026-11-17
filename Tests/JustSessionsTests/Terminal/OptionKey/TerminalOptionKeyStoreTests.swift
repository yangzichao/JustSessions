import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TerminalOptionKeyStoreTests {
    @Test func optionIsMetaUntilTurnedOff() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        #expect(TerminalOptionKeyStore(userDefaults: settings.userDefaults).optionIsMeta)
    }

    @Test(arguments: [false, true])
    func theChoiceIsKeptForTheNextLaunch(_ optionIsMeta: Bool) throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalOptionKeyStore(userDefaults: settings.userDefaults)
        // Choosing what is already chosen saves nothing, so each case first chooses the other.
        store.setOptionIsMeta(!optionIsMeta)

        store.setOptionIsMeta(optionIsMeta)

        #expect(store.optionIsMeta == optionIsMeta)
        #expect(TerminalOptionKeyStore(userDefaults: settings.userDefaults).optionIsMeta == optionIsMeta)
    }

    @Test func restoringTheTerminalAppearanceDefaultsKeepsTheChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalOptionKeyStore(userDefaults: settings.userDefaults).setOptionIsMeta(false)

        TerminalAppearanceStore(userDefaults: settings.userDefaults).restoreDefaults()

        #expect(!TerminalOptionKeyStore(userDefaults: settings.userDefaults).optionIsMeta)
    }

    /// A SwiftTerm terminal sends Esc before a key pressed with Option only while Option is Meta, and one already open
    /// follows a change.
    @Test func aSwiftTermTerminalFollowsTheChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalOptionKeyStore(userDefaults: settings.userDefaults)
        store.setOptionIsMeta(false)
        let terminal = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 400, height: 200),
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
            themeStore: AppThemeStore(userDefaults: settings.userDefaults),
            optionKeyStore: store
        )

        #expect(!terminal.optionAsMetaKey)

        store.setOptionIsMeta(true)

        #expect(terminal.optionAsMetaKey)
    }
}
