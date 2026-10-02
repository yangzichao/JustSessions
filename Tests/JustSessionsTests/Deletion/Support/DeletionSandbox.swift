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
    func savedConversation(
        _ provider: ConversationProvider = .claude,
        title: String = "Session",
        updatedAt: Date = .now
    ) throws -> Conversation {
        let sessionID = UUID().uuidString.lowercased()
        let sourceFile = directory.appendingPathComponent("\(sessionID).jsonl")
        try "{}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        return .fixture(
            provider: provider,
            sessionID: sessionID,
            projectPath: directory.path,
            title: title,
            updatedAt: updatedAt,
            sourceFile: sourceFile
        )
    }

    /// A Claude Code session on the SSH host `host`, whose mirrored copy exists in the sandbox, so a session that
    /// fails to delete stays listed as it does in the app.
    func savedConversation(onHost host: String, title: String = "Remote session", updatedAt: Date = .now) throws -> Conversation {
        let mirrorProjectFolder = directory
            .appendingPathComponent("mirror-\(host)")
            .appendingPathComponent("-home-me-project")
        try FileManager.default.createDirectory(at: mirrorProjectFolder, withIntermediateDirectories: true)
        let sessionID = UUID().uuidString.lowercased()
        let sourceFile = mirrorProjectFolder.appendingPathComponent("\(sessionID).jsonl")
        try "{}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        return .fixture(
            provider: .claude,
            sessionID: sessionID,
            projectPath: "/home/me/project",
            title: title,
            updatedAt: updatedAt,
            sourceFile: sourceFile,
            host: .ssh(host)
        )
    }

    /// A store that already lists `conversations`, each on its host; the SSH hosts among them are added. Without
    /// `adapters`, each tool's sessions on this Mac are deleted by removing their files; `remoteDeletion` stands in
    /// for the SSH hosts.
    func makeStore(
        listing conversations: [Conversation],
        adapters: [any ConversationAdapter]? = nil,
        remoteDeletion: RemoteConversationDeletion = RemoteConversationDeletion(
            runner: RemoteHostCommandRunner { _, _, _ in nil }
        )
    ) -> ConversationStore {
        let store = ConversationStore(
            adapters: adapters ?? ConversationProvider.allCases.map {
                FileBackedConversationAdapter(provider: $0, conversations: conversations)
            },
            userDefaults: userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            remoteDeletion: remoteDeletion,
            startsBackgroundPolling: false
        )
        let remoteHosts = conversations.compactMap(\.host.sshDestination).reduce(into: [String]()) { hosts, host in
            if !hosts.contains(host) { hosts.append(host) }
        }
        store.remoteHostList = RemoteHostList(hosts: remoteHosts)
        for host in [SessionHost.thisMac] + remoteHosts.map(SessionHost.ssh) {
            store.replaceConversations(on: host, with: conversations.filter { $0.host == host })
        }
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
