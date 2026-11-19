import Foundation
import Testing

@testable import JustSessions

@MainActor
struct TabCloseChoiceSettingsStoreTests {
    @Test func asksEachTimeUntilAChoiceIsSaved() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let store = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(store.choice(for: .thisMac) == .askEachTime)
        #expect(store.choice(for: .ssh("devbox")).endsTmuxSessionWithoutAsking == nil)

        store.setChoice(.keepRunning, for: .thisMac)
        let reopenedStore = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(reopenedStore.choice(for: .thisMac) == .keepRunning)
        #expect(reopenedStore.choice(for: .thisMac).endsTmuxSessionWithoutAsking == false)

        reopenedStore.setChoice(.endSession, for: .thisMac)
        #expect(TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice(for: .thisMac).endsTmuxSessionWithoutAsking == true)
    }

    @Test func eachHostKeepsItsOwnChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        let store = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        store.setChoice(.endSession, for: .thisMac)
        store.setChoice(.keepRunning, for: .ssh("devbox"))

        let reopenedStore = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(reopenedStore.choice(for: .thisMac) == .endSession)
        #expect(reopenedStore.choice(for: .ssh("devbox")) == .keepRunning)
        #expect(reopenedStore.choice(for: .ssh("buildbox")) == .askEachTime)

        reopenedStore.setChoice(.askEachTime, for: .ssh("devbox"))
        #expect(TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults).choice(for: .ssh("devbox")) == .askEachTime)
        #expect(reopenedStore.choices.sshHostChoices.isEmpty)
    }

    @Test func anUnknownSavedChoiceAsksEachTime() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }

        settings.userDefaults.set("closeQuietly", forKey: TabCloseChoicesByHost.thisMacUserDefaultsKey)
        settings.userDefaults.set(
            ["devbox": "closeQuietly", "buildbox": "keepRunning"], forKey: TabCloseChoicesByHost.sshHostsUserDefaultsKey)

        let store = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        #expect(store.choice(for: .thisMac) == .askEachTime)
        #expect(store.choice(for: .ssh("devbox")) == .askEachTime)
        #expect(store.choice(for: .ssh("buildbox")) == .keepRunning)
    }

    @Test func removingAnSSHHostForgetsItsChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let cacheRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        RemoteHostList(hosts: ["devbox", "buildbox"]).save(to: settings.userDefaults)
        let choiceStore = TabCloseChoiceSettingsStore(userDefaults: settings.userDefaults)
        choiceStore.setChoice(.keepRunning, for: .ssh("devbox"))
        choiceStore.setChoice(.endSession, for: .ssh("buildbox"))
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, tabCloseChoiceSettingsStore: choiceStore, startsBackgroundPolling: false
        )

        store.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: cacheRoot))

        let reloadedChoices = TabCloseChoicesByHost.load(from: settings.userDefaults)
        #expect(reloadedChoices.choice(for: .ssh("devbox")) == .askEachTime)
        #expect(reloadedChoices.choice(for: .ssh("buildbox")) == .endSession)
    }
}
