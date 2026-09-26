import Foundation
@testable import JustSessions

/// Session files in a temporary folder, listed by stores whose settings are the sandbox's own.
@MainActor
struct DeletionSandbox {
    let directory: URL
    let isolatedUserDefaults: IsolatedUserDefaults

    init() throws {
        directory = try makeTemporaryDirectory()
        isolatedUserDefaults = try IsolatedUserDefaults()
    }

    var userDefaults: UserDefaults { isolatedUserDefaults.userDefaults }

    /// A session of `provider` whose file exists in the sandbox.
    func savedConversation(_ provider: ConversationProvider = .claude, title: String = "Session") throws -> Conversation {
        let sessionID = UUID().uuidString.lowercased()
        let sourceFile = directory.appendingPathComponent("\(sessionID).jsonl")
        try "{}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        return .fixture(provider: provider, sessionID: sessionID, projectPath: directory.path, title: title, sourceFile: sourceFile)
    }

    /// A store that already lists `conversations` on this Mac. Without `adapters`, each tool's sessions are
    /// deleted by removing their files.
    func makeStore(listing conversations: [Conversation], adapters: [any ConversationAdapter]? = nil) -> ConversationStore {
        let store = ConversationStore(
            adapters: adapters ?? ConversationProvider.allCases.map {
                FileBackedConversationAdapter(provider: $0, conversations: conversations)
            },
            userDefaults: userDefaults
        )
        store.replaceConversations(on: .thisMac, with: conversations)
        return store
    }

    func fileExists(for conversation: Conversation) -> Bool {
        FileManager.default.fileExists(atPath: conversation.sourceFile.path)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
        isolatedUserDefaults.removeSuite()
    }
}
