import Foundation
import Testing

@testable import JustSessions

@MainActor
struct TerminalEngineLaunchTests {
    @Test(arguments: TerminalEngine.allCases)
    func aNewTabOpensWithTheChosenEngine(_ engine: TerminalEngine) throws {
        let settings = try IsolatedUserDefaults()
        let folder = try makeTemporaryDirectory()
        defer {
            settings.removeSuite()
            try? FileManager.default.removeItem(at: folder)
        }
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        engineStore.setEngine(engine)
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:]),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: engineStore,
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }

        store.openPlainTerminal(in: ProjectLocation(host: .thisMac, path: folder.path))

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.engine == engine)
        switch engine {
        case .ghostty: #expect(tab.terminalView is GhosttyTabTerminalView)
        case .swiftTerm: #expect(tab.terminalView is SelectableTerminalView)
        }
    }

    @Test func choosingAnotherEngineLeavesOpenTabsAsTheyAre() throws {
        let settings = try IsolatedUserDefaults()
        let folder = try makeTemporaryDirectory()
        defer {
            settings.removeSuite()
            try? FileManager.default.removeItem(at: folder)
        }
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        engineStore.setEngine(.swiftTerm)
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [], inheritedEnvironment: [:]),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: engineStore,
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        let location = ProjectLocation(host: .thisMac, path: folder.path)
        store.openPlainTerminal(in: location)

        engineStore.setEngine(.ghostty)
        store.openPlainTerminal(in: location)

        #expect(store.terminalSessions.map(\.engine) == [.swiftTerm, .ghostty])
        #expect(store.terminalSessions.first?.terminalView is SelectableTerminalView)
    }

    @Test func aReconnectedSSHTabKeepsTheEngineItOpenedWith() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        engineStore.setEngine(.swiftTerm)
        let store = ConversationStore(
            adapters: [],
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            terminalEngineStore: engineStore,
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        store.openPlainTerminal(in: ProjectLocation(host: .ssh("devbox"), path: "/home/me/paper"))
        let ended = try #require(store.terminalSessions.last)
        ended.processFinished(exitCode: 255)
        engineStore.setEngine(.ghostty)

        store.reconnectRemoteTerminal(ended.id)

        let reconnected = try #require(store.terminalSessions.last)
        #expect(reconnected !== ended)
        #expect(reconnected.engine == .swiftTerm)
        #expect(reconnected.terminalView is SelectableTerminalView)
    }
}
