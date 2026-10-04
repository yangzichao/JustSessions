import Foundation
import Testing
@testable import JustSessions

@MainActor
struct SidebarProjectPersistenceTests {
    @Test func removingAProjectKeepsItsFilesAndStaysRemovedAcrossRefreshAndRelaunch() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let sourceFile = temporaryDirectory.appendingPathComponent("session.jsonl")
        try "session contents".write(to: sourceFile, atomically: true, encoding: .utf8)
        let conversation = Conversation.fixture(projectPath: temporaryDirectory.path, sourceFile: sourceFile)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: [conversation])
        store.renameProject(conversation.projectDirectoryKey, to: "Saved project")
        store.setPinned(true, projectPath: conversation.projectDirectoryKey)

        store.removeProjectFromSidebar(conversation.projectDirectoryKey)
        store.replaceConversations(on: .thisMac, with: [conversation])

        #expect(store.sidebarProjectGroups.isEmpty)
        #expect(store.sidebarConversations.isEmpty)
        #expect(store.conversations.map(\.id) == [conversation.id])
        #expect(try String(contentsOf: sourceFile, encoding: .utf8) == "session contents")
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        relaunchedStore.replaceConversations(on: .thisMac, with: [conversation])
        #expect(relaunchedStore.sidebarProjectGroups.isEmpty)
        #expect(relaunchedStore.projectDisplayName(forProjectPath: conversation.projectDirectoryKey) == "Saved project")
        #expect(relaunchedStore.pinnedItems.isPinned(projectPath: conversation.projectDirectoryKey))
    }

    @Test func newSessionRestoresARemovedProjectAndClosingItsTabKeepsTheEmptyProject() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let projectPath = "/work/new-project"
        store.removeProjectFromSidebar(projectPath)
        let terminal = TerminalSession(
            conversation: nil,
            provider: .codex,
            projectPath: projectPath,
            action: .new,
            displayTitle: "New session",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
        )
        store.openTerminal(terminal)
        defer { store.closeAllTerminals() }

        #expect(store.sidebarProjectGroups.first?.pendingNewSessions.map(\.terminalID) == [terminal.id])
        store.removeProjectFromSidebar(terminal.projectDirectoryKey)
        #expect(store.sidebarProjectGroups.isEmpty)
        #expect(store.terminalSessions.map(\.id) == [terminal.id])
        #expect(store.selectedTerminalID == terminal.id)

        store.showProjectInSidebar(terminal.projectDirectoryKey)
        store.closeAllTerminals()
        let project = try #require(store.sidebarProjectGroups.first)
        #expect(project.id == terminal.projectDirectoryKey)
        #expect(project.sessionCount == 0)
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        #expect(relaunchedStore.sidebarProjectGroups.map(\.id) == [project.id])
    }

    /// Archived projects are ordered by display name across hosts. Restoring one lists its kept sessions again; the
    /// rest stay archived, including across a relaunch.
    @Test func archivedProjectsListByDisplayNameAndRestoringOneListsItsSessionsAgain() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let zebra = Conversation.fixture(projectPath: "/work/zebra")
        let remote = Conversation.fixture(projectPath: "/work/remote", host: .ssh("devbox"))
        store.replaceConversations(on: .thisMac, with: [zebra])
        store.replaceConversations(on: remote.host, with: [remote])
        store.renameProject(zebra.projectDirectoryKey, to: "Alpha tools")

        #expect(store.archivedProjectPaths.isEmpty)
        store.removeProjectsFromSidebar([zebra.projectDirectoryKey, remote.projectDirectoryKey])

        #expect(store.sidebarProjectGroups.isEmpty)
        #expect(store.archivedProjectPaths == [zebra.projectDirectoryKey, remote.projectDirectoryKey])
        // Each host heading's restore list holds only that host's projects.
        #expect(store.archivedProjectPaths(on: .thisMac) == [zebra.projectDirectoryKey])
        #expect(store.archivedProjectPaths(on: remote.host) == [remote.projectDirectoryKey])

        store.showProjectInSidebar(zebra.projectDirectoryKey)

        #expect(store.archivedProjectPaths == [remote.projectDirectoryKey])
        let restored = try #require(store.sidebarProjectGroups.first { $0.id == zebra.projectDirectoryKey })
        #expect(restored.conversations.map(\.id) == [zebra.id])
        #expect(restored.displayName == "Alpha tools")

        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        #expect(relaunchedStore.archivedProjectPaths == [remote.projectDirectoryKey])
    }

    @Test func samePathOnDifferentHostsHasIndependentSidebarMembership() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let local = Conversation.fixture(projectPath: "/work/project")
        let remote = Conversation.fixture(projectPath: "/work/project", host: .ssh("devbox"))
        store.replaceConversations(on: .thisMac, with: [local])
        store.replaceConversations(on: remote.host, with: [remote])

        store.removeProjectFromSidebar(local.projectDirectoryKey)
        store.replaceConversations(on: remote.host, with: [])
        #expect(store.sidebarProjectGroups.map(\.id) == [remote.projectDirectoryKey])
        #expect(store.sidebarProjectGroups.first?.sessionCount == 0)
        store.remoteHostList.remove("devbox")
        #expect(store.sidebarProjectGroups.isEmpty)
    }
}
