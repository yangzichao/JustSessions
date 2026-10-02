import Foundation
@testable import JustSessions

/// A project folder on this Mac, a stand-in `claude` that keeps running until its tab closes, the SSH hosts given, and
/// settings of its own.
@MainActor
struct TabReopeningSandbox {
    let root: URL
    let project: URL
    let binaryDirectory: URL
    let isolatedUserDefaults: IsolatedUserDefaults

    init(remoteHosts: [String] = []) throws {
        root = try makeTemporaryDirectory()
        project = root.appendingPathComponent("project")
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nexec sleep 30\n", to: binaryDirectory.appendingPathComponent("claude"))
        isolatedUserDefaults = try IsolatedUserDefaults()
        RemoteHostList(hosts: remoteHosts).save(to: isolatedUserDefaults.userDefaults)
    }

    var userDefaults: UserDefaults { isolatedUserDefaults.userDefaults }
    var projectLocation: ProjectLocation { ProjectLocation(host: .thisMac, path: project.path) }

    /// A Claude Code session in the project folder on this Mac, or at `remoteProjectPath` on an SSH host.
    func conversation(title: String = "Session", host: SessionHost = .thisMac, remoteProjectPath: String = "/srv/app") -> Conversation {
        Conversation.fixture(projectPath: host == .thisMac ? project.path : remoteProjectPath, title: title, host: host)
    }

    func makeStore() -> ConversationStore {
        ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [])],
            commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path]),
            userDefaults: userDefaults,
            startsBackgroundPolling: false
        )
    }

    func tearDown() {
        isolatedUserDefaults.removeSuite()
        try? FileManager.default.removeItem(at: root)
    }
}

extension ReopenableTerminalTab {
    static func session(_ conversation: Conversation, wasSelected: Bool = false) -> ReopenableTerminalTab {
        ReopenableTerminalTab(
            conversationID: conversation.id,
            projectDirectoryKey: conversation.projectDirectoryKey,
            wasSelected: wasSelected
        )
    }

    static func plainTerminal(in location: ProjectLocation, wasSelected: Bool = false) -> ReopenableTerminalTab {
        ReopenableTerminalTab(conversationID: nil, projectDirectoryKey: location.key, wasSelected: wasSelected)
    }
}
