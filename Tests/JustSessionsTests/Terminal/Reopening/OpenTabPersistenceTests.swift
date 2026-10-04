import Foundation
import Testing
@testable import JustSessions

/// One window restores the snapshot, and live updates merge every window without appending duplicates.
@MainActor
struct OpenTabPersistenceTests {
    private let first = ReopenableTerminalTab(conversationID: "claude:a", projectDirectoryKey: "/a", wasSelected: true)
    private let second = ReopenableTerminalTab(conversationID: nil, projectDirectoryKey: "/b", wasSelected: false)

    @Test func handsTheSavedTabsToTheFirstWindowOnly() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalTabsToReopen(tabs: [first]).save(to: settings.userDefaults)
        let tabsSavedAtQuit = OpenTabPersistence()

        #expect(tabsSavedAtQuit.take(from: settings.userDefaults) == [first])
        #expect(tabsSavedAtQuit.take(from: settings.userDefaults).isEmpty)
    }

    @Test func savesEveryWindowsTabsInPlaceOfTheLastQuits() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        TerminalTabsToReopen(tabs: [first, second]).save(to: settings.userDefaults)
        let tabsSavedAtQuit = OpenTabPersistence()
        let firstWindow = UUID()
        let secondWindow = UUID()

        tabsSavedAtQuit.update([second], for: firstWindow, in: settings.userDefaults)
        tabsSavedAtQuit.update([first], for: secondWindow, in: settings.userDefaults)
        tabsSavedAtQuit.update([second], for: firstWindow, in: settings.userDefaults)

        #expect(TerminalTabsToReopen.load(from: settings.userDefaults).tabs == [second, first])
    }

    @Test func closingAWindowDropsItsTabsUnlessItIsTheLastWindow() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let persistence = OpenTabPersistence()
        let firstWindow = UUID()
        let secondWindow = UUID()
        #expect(persistence.take(from: settings.userDefaults).isEmpty)
        persistence.update([first], for: firstWindow, in: settings.userDefaults)
        persistence.update([second], for: secondWindow, in: settings.userDefaults)

        persistence.closeWindow(firstWindow, in: settings.userDefaults)
        #expect(TerminalTabsToReopen.load(from: settings.userDefaults).tabs == [second])

        persistence.closeWindow(secondWindow, in: settings.userDefaults)
        #expect(TerminalTabsToReopen.load(from: settings.userDefaults).tabs == [second])
        #expect(persistence.take(from: settings.userDefaults) == [second])
        #expect(persistence.take(from: settings.userDefaults).isEmpty)
    }

    @Test func unreadableSavedTabsReopenNothing() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        settings.userDefaults.set(Data("not json".utf8), forKey: TerminalTabsToReopen.userDefaultsKey)

        #expect(OpenTabPersistence().take(from: settings.userDefaults).isEmpty)
    }
}
