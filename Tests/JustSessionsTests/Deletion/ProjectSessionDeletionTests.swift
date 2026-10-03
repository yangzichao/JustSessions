import Foundation
import Testing
@testable import JustSessions

struct ProjectSessionDeletionTests {
    @Test(arguments: ["single", "selection", "project"])
    @MainActor func deletingTheLastSessionKeepsTheProjectAcrossRefreshAndRelaunch(_ deletionKind: String) async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let projectFolder = try makeProject("kept-project", in: temporaryDirectory)
        let conversation = try savedConversation(.claude, project: projectFolder, in: temporaryDirectory)
        let store = makeStore(listing: [conversation], userDefaults: isolatedUserDefaults.userDefaults)
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        store.renameProject(conversation.projectDirectoryKey, to: "Kept project")
        store.setPinned(true, projectPath: conversation.projectDirectoryKey)

        switch deletionKind {
        case "single": store.delete(conversation)
        case "selection": store.deleteConversations([conversation])
        default: store.deleteSessions(in: conversation.projectDirectoryKey)
        }
        try await expectEventually { !store.isDeletingSessions }
        #expect(store.conversations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: conversation.sourceFile.path))
        #expect(store.sidebarProjectGroups.map(\.id) == [conversation.projectDirectoryKey])
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }

        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let keptProject = try #require(relaunchedStore.sidebarProjectGroups.first)
        #expect(keptProject.id == conversation.projectDirectoryKey)
        #expect(keptProject.sessionCount == 0)
        #expect(keptProject.displayName == "Kept project")
        #expect(keptProject.isPinned)
        #expect(keptProject.canStartNewSession)
        #expect(store.sidebarProjectGroups.map(\.id) == [keptProject.id])

        relaunchedStore.removeProjectFromSidebar(keptProject.id)
        #expect(relaunchedStore.sidebarProjectGroups.isEmpty)
        #expect(FileManager.default.fileExists(atPath: projectFolder.path))
        #expect(ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults).sidebarProjectGroups.isEmpty)
    }

    @Test @MainActor func projectDeletionDeletesEveryToolsSessionsAndKeepsOtherProjects() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let selectedProject = try makeProject("selected", in: temporaryDirectory)
        let otherProject = try makeProject("other", in: temporaryDirectory)

        let selectedClaude = try savedConversation(.claude, project: selectedProject, in: temporaryDirectory)
        let selectedCodex = try savedConversation(.codex, project: selectedProject, in: temporaryDirectory)
        let selectedOpenCode = try savedConversation(.opencode, project: selectedProject, in: temporaryDirectory)
        let otherClaude = try savedConversation(.claude, project: otherProject, in: temporaryDirectory)
        let store = makeStore(
            listing: [selectedClaude, selectedCodex, selectedOpenCode, otherClaude],
            userDefaults: isolatedUserDefaults.userDefaults
        )

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        let deletionPlan = store.deletionPlan(for: selectedProject.path)
        #expect(deletionPlan.deletableConversations.map(\.id).sorted() == [selectedClaude.id, selectedCodex.id, selectedOpenCode.id].sorted())

        store.deleteSessions(in: selectedProject.path)
        try await expectEventually { !store.isDeletingSessions }
        #expect(!FileManager.default.fileExists(atPath: selectedClaude.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedCodex.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedOpenCode.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: otherClaude.sourceFile.path))
        #expect(store.conversations.map(\.id) == [otherClaude.id])
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor func projectRemovalDeletesItsSessionsAndRemovesItFromTheSidebar() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let removedProject = try makeProject("removed", in: temporaryDirectory)
        let otherProject = try makeProject("other", in: temporaryDirectory)
        let removedClaude = try savedConversation(.claude, project: removedProject, in: temporaryDirectory)
        let runningOpenCode = try savedConversation(.opencode, project: removedProject, in: temporaryDirectory)
        let otherClaude = try savedConversation(.claude, project: otherProject, in: temporaryDirectory)
        let store = makeStore(listing: [removedClaude, runningOpenCode, otherClaude], userDefaults: isolatedUserDefaults.userDefaults)
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(runningOpenCode)]

        store.deleteSessionsAndRemoveProject(removedProject.path)
        try await expectEventually { !store.isDeletingSessions }
        #expect(!FileManager.default.fileExists(atPath: removedClaude.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: runningOpenCode.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: otherClaude.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: removedProject.path))
        #expect(store.sidebarProjectGroups.map(\.id) == [otherProject.path])

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        #expect(store.sidebarProjectGroups.map(\.id) == [otherProject.path])
        #expect(ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults).sidebarProjectGroups.map(\.id) == [otherProject.path])
    }

    @Test @MainActor func projectRemovalKeepsTheProjectWhenNothingCanBeDeleted() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let project = try makeProject("running-only", in: temporaryDirectory)
        let running = try savedConversation(.opencode, project: project, in: temporaryDirectory)
        let store = makeStore(listing: [running], userDefaults: isolatedUserDefaults.userDefaults)
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        store.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(running)]

        store.deleteSessionsAndRemoveProject(project.path)
        #expect(!store.isDeletingSessions)
        #expect(store.sidebarProjectGroups.map(\.id) == [project.path])
    }

    @Test @MainActor func selectedSessionDeletionSpansProjectsAndTools() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let firstProject = try makeProject("first", in: temporaryDirectory)
        let secondProject = try makeProject("second", in: temporaryDirectory)

        let selectedFirstClaude = try savedConversation(.claude, project: firstProject, in: temporaryDirectory)
        let unselectedFirstClaude = try savedConversation(.claude, project: firstProject, in: temporaryDirectory)
        let selectedSecondCodex = try savedConversation(.codex, project: secondProject, in: temporaryDirectory)
        let selectedOpenCode = try savedConversation(.opencode, project: secondProject, in: temporaryDirectory)
        let store = makeStore(
            listing: [selectedFirstClaude, unselectedFirstClaude, selectedSecondCodex, selectedOpenCode],
            userDefaults: isolatedUserDefaults.userDefaults
        )

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        let selectedConversations = [selectedFirstClaude, selectedSecondCodex, selectedOpenCode]
        let deletionPlan = store.deletionPlan(for: selectedConversations)
        #expect(deletionPlan.deletableConversations.map(\.id).sorted() == selectedConversations.map(\.id).sorted())

        store.deleteConversations(selectedConversations)
        #expect(store.isDeletionPending(for: selectedFirstClaude))
        #expect(!store.isDeletionPending(for: unselectedFirstClaude))
        try await expectEventually { !store.isDeletingSessions }
        #expect(!FileManager.default.fileExists(atPath: selectedFirstClaude.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedSecondCodex.sourceFile.path))
        #expect(!FileManager.default.fileExists(atPath: selectedOpenCode.sourceFile.path))
        #expect(FileManager.default.fileExists(atPath: unselectedFirstClaude.sourceFile.path))
        #expect(store.conversations.map(\.id) == [unselectedFirstClaude.id])
        #expect(store.errorMessage == nil)
    }

    private func makeProject(_ name: String, in temporaryDirectory: URL) throws -> URL {
        let project = temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        return project
    }

    private func savedConversation(_ provider: ConversationProvider, project: URL, in temporaryDirectory: URL) throws -> Conversation {
        let sessionID = UUID().uuidString
        let sourceFile = temporaryDirectory.appendingPathComponent("\(sessionID).jsonl")
        try "session".write(to: sourceFile, atomically: true, encoding: .utf8)
        return .fixture(provider: provider, sessionID: sessionID, projectPath: project.path, title: sessionID, sourceFile: sourceFile)
    }

    @MainActor private func makeStore(listing conversations: [Conversation], userDefaults: UserDefaults) -> ConversationStore {
        ConversationStore(
            adapters: ConversationProvider.allCases.map {
                FileBackedConversationAdapter(provider: $0, conversations: conversations)
            },
            userDefaults: userDefaults
        )
    }
}
