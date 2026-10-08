import Foundation
@testable import JustSessions

/// Two workspace windows' stores sharing one window registry, both listing the same Claude Code sessions of one
/// project on this Mac. Neither finds tmux. A tab a test opens runs nothing until it is started, so its CLI counts as
/// running until the test ends it.
@MainActor
struct TwoWindowSandbox {
    let root: URL
    let project: URL
    let conversations: [Conversation]
    let windowRegistry = WorkspaceWindowRegistry()
    let first: ConversationStore
    let second: ConversationStore
    private let isolatedUserDefaults: IsolatedUserDefaults

    init(sessionCount: Int = 1) throws {
        root = try makeTemporaryDirectory()
        project = root.appendingPathComponent("project")
        let binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent("claude"))
        let project = project
        conversations = (1...sessionCount).map { index in
            let sessionID = UUID().uuidString.lowercased()
            return Conversation(
                provider: .claude,
                sessionID: sessionID,
                projectPath: project.path,
                suggestedTitle: "Session \(index)",
                updatedAt: .now,
                sourceFile: project.appendingPathComponent("\(sessionID).jsonl")
            )
        }
        isolatedUserDefaults = try IsolatedUserDefaults()
        let makeStore = { [conversations, windowRegistry, isolatedUserDefaults] in
            let store = ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: conversations)],
                commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path], inheritedEnvironment: [:]),
                userDefaults: isolatedUserDefaults.userDefaults,
                sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: windowRegistry,
                startsBackgroundPolling: false
            )
            store.replaceConversations(on: .thisMac, with: conversations)
            return store
        }
        first = makeStore()
        second = makeStore()
    }

    var conversation: Conversation { conversations[0] }

    /// Resumes the session in `store`'s window and returns its tab, leaving no tab selected there, as when another
    /// tab or a preview shows.
    func openTab(of conversation: Conversation, in store: ConversationStore) -> TerminalSession? {
        store.launch(conversation, action: .resume)
        let tab = store.runningTerminal(for: conversation)
        store.selectTerminal(nil)
        return tab
    }

    func tearDown() {
        first.closeAllTerminals()
        second.closeAllTerminals()
        isolatedUserDefaults.removeSuite()
        try? FileManager.default.removeItem(at: root)
    }
}
