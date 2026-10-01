import Foundation
import Testing
@testable import JustSessions

/// A plain terminal is a tab, not a session: nothing waits for it to save one, watches it, or counts it as running.
@MainActor
struct PlainTerminalTabTests {
    @Test func opensASelectedTabThatIsNoSession() throws {
        let projectDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }
        let location = ProjectLocation(host: .thisMac, path: projectDirectory.path)

        store.openPlainTerminal(in: location)

        let tab = try #require(store.terminalSessions.last)
        #expect(store.selectedTerminalID == tab.id)
        #expect(tab.isPlainTerminal)
        #expect(tab.displayTitle == "Terminal · \(store.projectDisplayName(forProjectPath: location.key))")
        #expect(tab.command.workingDirectory == projectDirectory.standardizedFileURL.path)
        #expect(tab.tmuxSessionName == nil)
        #expect(!tab.startsNewSession)
        #expect(tab.pendingNewSession == nil)
        #expect(tab.waitingNewSessionTab == nil)
        #expect(tab.cliActivityProbe == nil)
        #expect(store.pendingNewSessions.isEmpty)
        #expect(store.activitySummary(forProjectDirectoryKey: tab.projectDirectoryKey).runningCount == 0)
    }

    @Test func showsAnErrorInsteadOfATabForAMissingFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        store.openPlainTerminal(in: ProjectLocation(host: .thisMac, path: root.appendingPathComponent("gone").path))

        #expect(store.terminalSessions.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func opensOnAnSSHHostOverSSH() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        defer { store.closeAllTerminals() }

        store.openPlainTerminal(in: ProjectLocation(host: .ssh("devbox"), path: "/home/me/paper"))

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.isPlainTerminal)
        #expect(tab.projectDirectoryKey == "ssh://devbox/home/me/paper")
        #expect(tab.command.executablePath == "/usr/bin/ssh")
        #expect(tab.waitingTabForAppearingSession == nil)
        #expect(!tab.isWaitingForAppearingSession)
    }
}
