import Foundation
import Testing
@testable import JustSessions

/// The host heading's Use this host's tmux prefix: saved per SSH host, sent to the host's sessions at once, and used
/// by every tab opened there afterwards.
@MainActor
struct RemoteTmuxPrefixChoiceTests {
    @Test func choiceIsSavedPerHostAndSentToTheHostsSessionsAtOnce() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = makeStore(settings)
        let recorder = RemoteCommandRecorder()

        store.setUsesTmuxPrefix(true, on: "devbox", remoteRunner: recorder.runner(answering: (0, "")))

        #expect(store.usesTmuxPrefix(on: .ssh("devbox")))
        #expect(!store.usesTmuxPrefix(on: .ssh("buildbox")))
        #expect(!store.usesTmuxPrefix(on: .thisMac))
        #expect(RemoteHostsUsingTmuxPrefix.load(from: settings.userDefaults).hosts == ["devbox"])
        try await expectEventually { recorder.commands.count == 1 }
        #expect(recorder.commands.first?.host == "devbox")
        #expect(recorder.commands.first?.command == RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: true, on: "devbox"))

        // Choosing what the host already uses sends nothing.
        store.setUsesTmuxPrefix(true, on: "devbox", remoteRunner: recorder.runner(answering: (0, "")))
        store.setUsesTmuxPrefix(false, on: "buildbox", remoteRunner: recorder.runner(answering: (0, "")))
        store.setUsesTmuxPrefix(false, on: "devbox", remoteRunner: recorder.runner(answering: (0, "")))
        try await expectEventually { recorder.commands.count == 2 }
        #expect(recorder.commands.last?.command == RemoteTmuxCommands.setPrefixOptionsCommand(usingHostPrefix: false, on: "devbox"))
        #expect(!store.usesTmuxPrefix(on: .ssh("devbox")))
    }

    @Test func tabsOpenedOnAHostUseItsChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = makeStore(settings)
        defer { store.closeAllTerminals() }
        let onDevbox = Conversation.fixture(provider: .pi, projectPath: "/srv/app", host: .ssh("devbox"))
        let onBuildbox = Conversation.fixture(provider: .pi, projectPath: "/srv/app", host: .ssh("buildbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [onDevbox])
        store.replaceConversations(on: .ssh("buildbox"), with: [onBuildbox])
        store.setUsesTmuxPrefix(true, on: "devbox", remoteRunner: RemoteCommandRecorder().runner(answering: (0, "")))

        store.launch(onDevbox, action: .resume)
        store.launch(onBuildbox, action: .resume)
        store.launchNewRemoteSession(provider: .pi, host: "devbox", projectPath: "/srv/app")

        let commandsByHost = Dictionary(grouping: store.terminalSessions, by: \.host)
            .mapValues { $0.compactMap(\.command.arguments.last) }
        #expect(commandsByHost[.ssh("devbox")]?.count == 2)
        #expect(commandsByHost[.ssh("devbox")]?.allSatisfy(usesHostPrefix) == true)
        #expect(commandsByHost[.ssh("buildbox")]?.allSatisfy(hasNoPrefixKeys) == true)
    }

    @Test func aReopenedTabWaitingToBeShownIsRemadeWithTheNewChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = makeStore(settings)
        defer { store.closeAllTerminals() }
        let conversation = Conversation.fixture(provider: .pi, projectPath: "/srv/app", host: .ssh("devbox"))
        store.replaceConversations(on: .ssh("devbox"), with: [conversation])
        let waitingTab = try #require(try store.makeTerminal(for: conversation, action: .resume, startsOnceShown: true))
        store.insertReopenedTerminal(waitingTab, at: 0, selecting: false)
        #expect(hasNoPrefixKeys(waitingTab.command.arguments.last ?? ""))

        store.setUsesTmuxPrefix(true, on: "devbox", remoteRunner: RemoteCommandRecorder().runner(answering: (0, "")))

        let remadeTab = try #require(store.terminalSessions.first)
        #expect(store.terminalSessions.count == 1)
        #expect(remadeTab.id != waitingTab.id)
        #expect(remadeTab.isWaitingToBeShown)
        #expect(remadeTab.conversation?.id == conversation.id)
        #expect(usesHostPrefix(remadeTab.command.arguments.last ?? ""))
    }

    @Test func removingTheHostForgetsItsChoice() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let cacheRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let store = makeStore(settings)
        store.setUsesTmuxPrefix(true, on: "devbox", remoteRunner: RemoteCommandRecorder().runner(answering: (0, "")))

        store.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: cacheRoot))

        #expect(!store.usesTmuxPrefix(on: .ssh("devbox")))
        #expect(RemoteHostsUsingTmuxPrefix.load(from: settings.userDefaults).hosts.isEmpty)
    }

    private func makeStore(_ settings: IsolatedUserDefaults) -> ConversationStore {
        RemoteHostList(hosts: ["devbox", "buildbox"]).save(to: settings.userDefaults)
        return ConversationStore(
            adapters: [PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))],
            userDefaults: settings.userDefaults,
            startsBackgroundPolling: false
        )
    }

    private func usesHostPrefix(_ remoteCommand: String) -> Bool {
        remoteCommand.contains("set-option -u prefix") && !remoteCommand.contains("prefix None")
    }

    private func hasNoPrefixKeys(_ remoteCommand: String) -> Bool {
        remoteCommand.contains("set-option prefix None") && remoteCommand.contains("set-option prefix2 None")
    }
}
