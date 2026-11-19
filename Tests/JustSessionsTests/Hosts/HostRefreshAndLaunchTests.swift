import Foundation
import Testing

@testable import JustSessions

struct HostRefreshAndLaunchTests {
    @Test @MainActor func thisMacScanReportsItsStatusAndKeepsSSHHostSessions() async throws {
        let onThisMac = conversation(project: "/Users/me/app")
        let onDevbox = conversation(project: "/home/me/api").onHost(.ssh("devbox"))
        let store = ConversationStore(adapters: [StaticConversationAdapter(discoveredConversations: [onThisMac])])
        store.replaceConversations(on: .ssh("devbox"), with: [onDevbox])
        store.hostRefreshStatuses[.ssh("devbox")] = .refreshing

        store.refresh(.thisMac)
        #expect(store.hostRefreshStatuses[.thisMac] == .refreshing)
        #expect(store.isScanningThisMac)
        try await expectEventually { !store.isScanningThisMac }

        #expect(Set(store.conversations.map(\.id)) == [onThisMac.id, onDevbox.id])
        guard case .refreshed? = store.hostRefreshStatuses[.thisMac] else {
            Issue.record("This Mac's scan should end as refreshed, not \(String(describing: store.hostRefreshStatuses[.thisMac]))")
            return
        }
        #expect(!store.isScanningThisMac)
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == .refreshing)
    }

    @Test @MainActor func thisMacScanFailureShowsOnItsHeadingInsteadOfAnAlert() async throws {
        let store = ConversationStore(adapters: [UnreadableConversationAdapter()])

        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }

        #expect(store.hostRefreshStatuses[.thisMac] == .failed("Codex: The session folder could not be read."))
        #expect(store.errorMessage == nil)
    }

    @Test @MainActor func newSessionOnAnSSHHostStartsInTheFolderTheHostReports() async throws {
        let store = ConversationStore(adapters: [])
        let recorder = RemoteCommandRecorder()

        try await store.launchNewSession(
            provider: .codex,
            host: .ssh("devbox"),
            folder: "~/api",
            resolver: RemoteFolderResolver(runner: recorder.runner(answering: (0, "/home/me/api\n")))
        )

        let tab = try #require(store.terminalSessions.last)
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.projectPath == "/home/me/api")
        #expect(tab.command.executablePath == "/usr/bin/ssh")
        #expect(tab.pendingNewSession?.projectDirectoryKey == "ssh://devbox/home/me/api")
        store.closeAllTerminals()
    }

    @Test @MainActor func missingFolderOnAnSSHHostOpensNoTab() async {
        let store = ConversationStore(adapters: [])
        let resolver = RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: (2, "sh: cd: can't cd to gone")))

        await #expect(throws: RemoteFolderResolutionError.missingFolder(host: "devbox", folder: "~/gone")) {
            try await store.launchNewSession(provider: .claude, host: .ssh("devbox"), folder: "~/gone", resolver: resolver)
        }
        #expect(store.terminalSessions.isEmpty)
    }

    @Test @MainActor func aMissingFolderOnAnSSHHostIsCreatedThereWhenAsked() async throws {
        let store = ConversationStore(adapters: [])
        let recorder = RemoteCommandRecorder()

        try await store.launchNewSession(
            provider: .codex,
            host: .ssh("devbox"),
            folder: "~/new",
            creatingMissingFolder: true,
            resolver: RemoteFolderResolver(runner: recorder.runner(answering: (0, "/home/me/new\n")))
        )

        let tab = try #require(store.terminalSessions.last)
        #expect(recorder.commands.map(\.command) == [RemoteFolderResolver.lookupCommand(for: "~/new", creatingMissingFolder: true)])
        #expect(tab.projectPath == "/home/me/new")
        store.closeAllTerminals()
    }

    @Test @MainActor func missingFolderOnThisMacOpensNoTabAndIsNotCreated() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let missingFolder = root.appendingPathComponent("gone").path
        let store = ConversationStore(adapters: [])

        await #expect(throws: ThisMacFolderResolutionError.missingFolder(folder: missingFolder)) {
            try await store.launchNewSession(provider: .claude, host: .thisMac, folder: missingFolder)
        }
        await #expect(throws: ThisMacFolderResolutionError.missingFolder(folder: missingFolder)) {
            try await store.openPlainTerminal(host: .thisMac, folder: missingFolder)
        }
        #expect(store.terminalSessions.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: missingFolder))
    }

    @Test @MainActor func plainTerminalOnThisMacCreatesAMissingFolderWhenAsked() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let newFolder = root.appendingPathComponent("new/app")
        let store = ConversationStore(adapters: [])

        try await store.openPlainTerminal(host: .thisMac, folder: newFolder.path, creatingMissingFolder: true)

        let tab = try #require(store.terminalSessions.last)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: newFolder.path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(tab.command.workingDirectory == newFolder.standardizedFileURL.path)
        store.closeAllTerminals()
    }

    @Test @MainActor func plainTerminalOnAnSSHHostOpensInTheFolderTheHostReports() async throws {
        let store = ConversationStore(adapters: [])
        let recorder = RemoteCommandRecorder()

        try await store.openPlainTerminal(
            host: .ssh("devbox"),
            folder: "~/api",
            resolver: RemoteFolderResolver(runner: recorder.runner(answering: (0, "/home/me/api\n")))
        )

        let tab = try #require(store.terminalSessions.last)
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(tab.host == .ssh("devbox"))
        #expect(tab.projectPath == "/home/me/api")
        #expect(tab.provider == nil)
        #expect(tab.pendingNewSession == nil)
        store.closeAllTerminals()
    }

    @Test @MainActor func plainTerminalInAMissingFolderOnAnSSHHostOpensNoTab() async {
        let store = ConversationStore(adapters: [])
        let resolver = RemoteFolderResolver(runner: RemoteCommandRecorder().runner(answering: (2, "sh: cd: can't cd to gone")))

        await #expect(throws: RemoteFolderResolutionError.missingFolder(host: "devbox", folder: "~/gone")) {
            try await store.openPlainTerminal(host: .ssh("devbox"), folder: "~/gone", resolver: resolver)
        }
        #expect(store.terminalSessions.isEmpty)
    }

    private func conversation(project: String) -> Conversation {
        let sessionID = UUID().uuidString
        return Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: project,
            suggestedTitle: "Session",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
    }
}

private struct UnreadableConversationAdapter: ConversationAdapter {
    struct UnreadableFolderError: LocalizedError {
        var errorDescription: String? { "The session folder could not be read." }
    }

    let provider: ConversationProvider = .codex

    func discover(cancellation: ConversationDiscoveryCancellation) throws -> [Conversation] {
        try cancellation.checkCancellation()
        throw UnreadableFolderError()
    }
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] { [] }
    func delete(_ conversation: Conversation) throws {}
}
