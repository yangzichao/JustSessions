import Foundation
import Testing
@testable import JustSessions

@MainActor
struct SidebarProjectBatchRemovalTests {
    @Test func batchRemovalPersistsAcrossHostsAndKeepsSessionDataAndOpenTerminals() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let localSourceFile = temporaryDirectory.appendingPathComponent("local-session.jsonl")
        let remoteSourceFile = temporaryDirectory.appendingPathComponent("remote-session.jsonl")
        try "local session contents".write(to: localSourceFile, atomically: true, encoding: .utf8)
        try "remote session contents".write(to: remoteSourceFile, atomically: true, encoding: .utf8)
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)

        let selectedLocal = Conversation.fixture(projectPath: temporaryDirectory.path, sourceFile: localSourceFile)
        let selectedRemote = Conversation.fixture(projectPath: "/work/shared", sourceFile: remoteSourceFile, host: .ssh("devbox"))
        let unselectedLocal = Conversation.fixture(projectPath: selectedRemote.projectPath)
        let unselectedRemote = Conversation.fixture(projectPath: "/work/kept", host: selectedRemote.host)
        let emptyProjectPath = "/work/empty"
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.replaceConversations(on: .thisMac, with: [selectedLocal, unselectedLocal])
        store.replaceConversations(on: selectedRemote.host, with: [selectedRemote, unselectedRemote])
        store.showProjectInSidebar(emptyProjectPath)
        store.rename(selectedLocal, to: "Saved session")
        let removedProjectIDs: Set<String> = [selectedLocal.projectDirectoryKey, selectedRemote.projectDirectoryKey, emptyProjectPath]
        for projectID in removedProjectIDs {
            store.renameProject(projectID, to: "Saved project")
            store.setPinned(true, projectPath: projectID)
        }
        let terminal = TerminalSession(
            conversation: selectedLocal,
            provider: selectedLocal.provider,
            projectPath: selectedLocal.projectPath,
            action: .resume,
            displayTitle: "Open session",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: selectedLocal.projectPath, environment: [])
        )
        store.openTerminal(terminal)
        defer { store.closeAllTerminals() }

        store.removeProjectsFromSidebar(removedProjectIDs)
        store.replaceConversations(on: .thisMac, with: [selectedLocal, unselectedLocal])
        store.replaceConversations(on: selectedRemote.host, with: [selectedRemote, unselectedRemote])

        let keptProjectIDs: Set<String> = [unselectedLocal.projectDirectoryKey, unselectedRemote.projectDirectoryKey]
        #expect(Set(store.sidebarProjectGroups.map(\.id)) == keptProjectIDs)
        #expect(Set(store.sidebarConversations.map(\.id)) == [unselectedLocal.id, unselectedRemote.id])
        #expect(Set(store.conversations.map(\.id)) == [selectedLocal.id, selectedRemote.id, unselectedLocal.id, unselectedRemote.id])
        #expect(store.terminalSessions.map(\.id) == [terminal.id])
        #expect(store.selectedTerminalID == terminal.id)
        #expect(try String(contentsOf: localSourceFile, encoding: .utf8) == "local session contents")
        #expect(try String(contentsOf: remoteSourceFile, encoding: .utf8) == "remote session contents")
        #expect(FileManager.default.fileExists(atPath: temporaryDirectory.path))
        #expect(SidebarProjectList.load(from: isolatedUserDefaults.userDefaults).removedProjectPaths == removedProjectIDs)

        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        relaunchedStore.replaceConversations(on: .thisMac, with: [selectedLocal, unselectedLocal])
        relaunchedStore.replaceConversations(on: selectedRemote.host, with: [selectedRemote, unselectedRemote])
        #expect(Set(relaunchedStore.sidebarProjectGroups.map(\.id)) == keptProjectIDs)
        #expect(relaunchedStore.title(for: selectedLocal) == "Saved session")
        for projectID in removedProjectIDs {
            #expect(relaunchedStore.projectDisplayName(forProjectPath: projectID) == "Saved project")
            #expect(relaunchedStore.pinnedItems.isPinned(projectPath: projectID))
        }

        relaunchedStore.showProjectInSidebar(selectedRemote.projectDirectoryKey)
        #expect(Set(relaunchedStore.sidebarProjectGroups.map(\.id)) == keptProjectIDs.union([selectedRemote.projectDirectoryKey]))
        #expect(relaunchedStore.sidebarProjectList.removedProjectPaths == removedProjectIDs.subtracting([selectedRemote.projectDirectoryKey]))
    }

    @Test func emptyBatchKeepsSidebarMembership() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        store.showProjectInSidebar("/work/kept")
        store.removeProjectFromSidebar("/work/hidden")
        let savedList = store.sidebarProjectList

        store.removeProjectsFromSidebar([])

        #expect(store.sidebarProjectList == savedList)
        #expect(SidebarProjectList.load(from: isolatedUserDefaults.userDefaults) == savedList)
    }
}
