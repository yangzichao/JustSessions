import Foundation
@testable import JustSessions

/// A project folder on this Mac with stand-in `claude` and `codex` CLIs that exit at once, settings of its own, and one
/// engine store that every window's store here shares, as the app's windows share theirs. No tmux is found, and a tab
/// runs nothing until a test starts it, so nothing connects to an SSH host.
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

    /// A Claude Code session in the project folder on this Mac, or at `/srv/project` on an SSH host.
    func conversation(host: SessionHost = .thisMac) -> Conversation {
        Conversation.fixture(projectPath: host == .thisMac ? project.path : "/srv/project", host: host)
    }

    /// A window's store, listing `conversations` on their hosts.
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
