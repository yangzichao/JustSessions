import Foundation

@testable import JustSessions

@MainActor
final class TerminalEngineLaunchSandbox {
    let root: URL
    let project: URL
    let binaryDirectory: URL
    let engineStore: TerminalEngineStore
    let windowRegistry = WorkspaceWindowRegistry()
    private let settings: IsolatedUserDefaults
    private var stores: [ConversationStore] = []

    init(engine: TerminalEngine) throws {
        root = try makeTemporaryDirectory()
        project = root.appendingPathComponent("project")
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        for cli in ["claude", "codex"] {
            try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent(cli))
        }
        settings = try IsolatedUserDefaults()
        engineStore = TerminalEngineStore(userDefaults: settings.userDefaults)
        engineStore.setEngine(engine)
    }

    var userDefaults: UserDefaults { settings.userDefaults }
    var projectLocation: ProjectLocation { ProjectLocation(host: .thisMac, path: project.path) }

    func conversation(host: SessionHost = .thisMac) -> Conversation {
        Conversation.fixture(projectPath: host == .thisMac ? project.path : "/srv/project", host: host)
    }

    func makeStore(listing conversations: [Conversation] = []) -> ConversationStore {
        let store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: conversations)],
            commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path], inheritedEnvironment: [:]),
            userDefaults: userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            windowRegistry: windowRegistry,
            terminalEngineStore: engineStore,
            startsBackgroundPolling: false
        )
        for host in Set(conversations.map(\.host)) {
            if let destination = host.sshDestination { _ = store.remoteHostList.add(destination) }
            store.replaceConversations(on: host, with: conversations.filter { $0.host == host })
        }
        stores.append(store)
        return store
    }

    func tearDown() {
        for store in stores { store.closeAllTerminals() }
        settings.removeSuite()
        try? FileManager.default.removeItem(at: root)
    }
}
