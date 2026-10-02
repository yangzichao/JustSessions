import Foundation
import Testing
@testable import JustSessions

/// One window per launch reopens the last quit's tabs, and every window's tabs are saved at quit.
@MainActor
struct TabsSavedAtQuitTests {
    private let first = ReopenableTerminalTab(conversationID: "claude:a", projectDirectoryKey: "/a", wasSelected: true)
    private let second = ReopenableTerminalTab(conversationID: nil, projectDirectoryKey: "/b", wasSelected: false)

    @Test func handsTheSavedTabsToTheFirstWindowOnly() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalTabsToReopen(tabs: [first]).save(to: settings.userDefaults)
        let tabsSavedAtQuit = TabsSavedAtQuit()

        #expect(tabsSavedAtQuit.take(from: settings.userDefaults) == [first])
        #expect(tabsSavedAtQuit.take(from: settings.userDefaults).isEmpty)
    }

    @Test func savesEveryWindowsTabsInPlaceOfTheLastQuits() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalTabsToReopen(tabs: [first, second]).save(to: settings.userDefaults)
        let tabsSavedAtQuit = TabsSavedAtQuit()

        tabsSavedAtQuit.save([second], to: settings.userDefaults)
        tabsSavedAtQuit.save([first], to: settings.userDefaults)

        #expect(TerminalTabsToReopen.load(from: settings.userDefaults).tabs == [second, first])
    }

    @Test func unreadableSavedTabsReopenNothing() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(Data("not json".utf8), forKey: TerminalTabsToReopen.userDefaultsKey)

        #expect(TabsSavedAtQuit().take(from: settings.userDefaults).isEmpty)
    }
}
