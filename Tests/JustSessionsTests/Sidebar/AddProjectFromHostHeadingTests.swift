import Foundation
import Testing
@testable import JustSessions

@MainActor
struct AddProjectFromHostHeadingTests {
    /// The folder is listed with no sessions under the key its sessions will have, and stays across a relaunch.
    @Test func aFolderOnThisMacIsListedAsAnEmptyProjectUnderItsResolvedPath() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let projectFolder = temporaryDirectory.appendingPathComponent("app")
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)

        let projectPath = try await store.addProjectToSidebar(folder: projectFolder.path, on: .thisMac)

        #expect(projectPath == ProjectLocation(host: .thisMac, path: projectFolder.path).key)
        let project = try #require(store.sidebarProjectGroups.first)
        #expect(store.sidebarProjectGroups.count == 1)
        #expect(project.id == projectPath)
        #expect(project.sessionCount == 0)
        let relaunchedStore = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        #expect(relaunchedStore.sidebarProjectGroups.map(\.id) == [projectPath])
    }

    @Test func addingAnArchivedFolderRestoresItWithItsSessions() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let conversation = Conversation.fixture(projectPath: "/work/archived")
        store.replaceConversations(on: .thisMac, with: [conversation])
        store.removeProjectFromSidebar(conversation.projectDirectoryKey)

        try await store.addProjectToSidebar(folder: "/work/archived", on: .thisMac)

        #expect(store.archivedProjectPaths.isEmpty)
        #expect(store.sidebarProjectGroups.map(\.id) == [conversation.projectDirectoryKey])
        #expect(store.sidebarConversations.map(\.id) == [conversation.id])
    }

    @Test func aFolderOnAnSSHHostIsListedUnderThePathTheHostReports() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let recorder = RemoteCommandRecorder()

        let projectPath = try await store.addProjectToSidebar(
            folder: "~/api",
            on: .ssh("devbox"),
            resolver: RemoteFolderResolver(runner: recorder.runner(answering: (0, "/home/me/api\n")))
        )

        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(projectPath == "ssh://devbox/home/me/api")
        #expect(store.sidebarProjectGroups.map(\.id) == ["ssh://devbox/home/me/api"])
        #expect(store.sidebarProjectGroups.first?.host == .ssh("devbox"))
    }

    @Test func aMissingFolderOnAnSSHHostIsNotListed() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let resolver = RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: (2, "sh: cd: can't cd to gone")))

        await #expect(throws: RemoteFolderResolutionError.missingFolder(host: "devbox", folder: "~/gone")) {
            try await store.addProjectToSidebar(folder: "~/gone", on: .ssh("devbox"), resolver: resolver)
        }
        #expect(store.sidebarProjectGroups.isEmpty)
    }

    @Test func aMissingFolderOnAnSSHHostIsCreatedThereWhenAsked() async throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        RemoteHostList(hosts: ["devbox"]).save(to: isolatedUserDefaults.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: isolatedUserDefaults.userDefaults)
        let recorder = RemoteCommandRecorder()

        let projectPath = try await store.addProjectToSidebar(
            folder: "~/new",
            on: .ssh("devbox"),
            creatingMissingFolder: true,
            resolver: RemoteFolderResolver(runner: recorder.runner(answering: (0, "/home/me/new\n")))
        )

        #expect(recorder.commands.map(\.command) == [RemoteFolderResolver.lookupCommand(for: "~/new", creatingMissingFolder: true)])
        #expect(projectPath == "ssh://devbox/home/me/new")
        #expect(store.sidebarProjectGroups.map(\.id) == ["ssh://devbox/home/me/new"])
    }
}
