import Foundation
import Testing
@testable import JustSessions

@MainActor
struct BranchTabLinkTests {
    private static let forkedSessionID = "66666666-6666-4666-8666-666666666666"
    private static let forkSessionID = "77777777-7777-4777-8777-777777777777"

    @Test func branchTabIsListedUnderItsProjectRightAwayAndLinksToItsFork() async throws {
        let root = try makeRootWithProjectFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let forked = Self.conversation(sessionID: Self.forkedSessionID, under: root)
        let fork = Self.conversation(sessionID: Self.forkSessionID, under: root)
        let store = try await makeStore(discovering: [forked, fork], under: root)

        store.launch(forked, action: .branch)

        let tab = try #require(store.terminalSessions.last)
        #expect(tab.action == .branch)
        #expect(tab.conversation == nil)
        #expect(tab.waitingNewSessionTab.branchedFromSessionID == Self.forkedSessionID)
        #expect(!store.hasTerminal(for: forked))
        let project = try #require(ProjectConversationGroup.grouped(
            store.conversations,
            pendingNewSessions: store.pendingNewSessions
        ).first)
        #expect(project.pendingNewSessions.map(\.terminalID) == [tab.id])
        #expect(project.conversations.count == 2)

        #expect(store.linkWaitingNewSessionTab(tab, toSessionID: Self.forkSessionID))
        #expect(tab.conversation?.id == fork.id)
        #expect(store.pendingNewSessions.isEmpty)
        #expect(store.hasTerminal(for: fork))
        #expect(!store.hasTerminal(for: forked))
        store.closeAllTerminals()
    }

    @Test func resumingTheForkedSessionOpensItsOwnTabInsteadOfTheBranch() async throws {
        let root = try makeRootWithProjectFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let forked = Self.conversation(sessionID: Self.forkedSessionID, under: root)
        let store = try await makeStore(discovering: [forked], under: root)

        store.launch(forked, action: .branch)
        store.launch(forked, action: .resume)

        #expect(store.terminalSessions.map(\.action) == [.branch, .resume])
        #expect(store.terminalSessions.last?.conversation?.id == forked.id)
        #expect(store.selectedTerminalID == store.terminalSessions.last?.id)
        store.closeAllTerminals()
    }

    /// A store that lists `conversations` and launches a stand-in `claude` found under `root/bin`.
    private func makeStore(discovering conversations: [Conversation], under root: URL) async throws -> ConversationStore {
        let binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        let executable = binaryDirectory.appendingPathComponent("claude")
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: executable)
        let store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: conversations)],
            commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path])
        )
        store.refreshThisMac()
        for _ in 0..<100 where store.isScanningThisMac || store.conversations.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.conversations.count == conversations.count)
        return store
    }

    /// A temporary folder holding the `project` folder the sessions run in.
    private func makeRootWithProjectFolder() throws -> URL {
        let root = try makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("project"), withIntermediateDirectories: true)
        return root
    }

    private static func conversation(sessionID: String, under root: URL) -> Conversation {
        let projectPath = root.appendingPathComponent("project").path
        return Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: "Original",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "\(projectPath)/\(sessionID).jsonl")
        )
    }
}
