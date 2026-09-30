import Foundation
import Testing
@testable import JustSessions

/// Clicking a session in the sidebar shows its running CLI when there is one, and otherwise leaves it to the preview.
@MainActor
struct RunningCLISelectionTests {
    @Test func aSessionWhoseTabRunsShowsThatTabWithoutOpeningAnother() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }

        store.launch(sandbox.conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        store.selectTerminal(nil)

        #expect(store.showRunningCLI(for: sandbox.conversation))
        #expect(store.selectedTerminalID == tab.id)
        #expect(store.terminalSessions.count == 1)
    }

    @Test func aSessionWithNoRunningCLIIsLeftToItsPreview() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }

        #expect(!store.showRunningCLI(for: sandbox.conversation))
        #expect(store.terminalSessions.isEmpty)
        #expect(store.selectedTerminalID == nil)
    }

    @Test func aSessionWhoseTabEndedIsLeftToItsPreview() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }

        store.launch(sandbox.conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        tab.processFinished(exitCode: 0)
        store.selectTerminal(nil)

        #expect(!store.showRunningCLI(for: sandbox.conversation))
        #expect(store.selectedTerminalID == nil)
        #expect(store.terminalSessions.count == 1)
    }

    @Test func aSessionRunningInTmuxWithNoTabReattachesInANewTab() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.setTmuxSessionNames([TmuxSessionName.forConversation(sandbox.conversation)], on: .thisMac)

        #expect(store.showRunningCLI(for: sandbox.conversation))
        let tab = try #require(store.terminalSessions.last)
        #expect(tab.action == .resume)
        #expect(tab.conversation?.id == sandbox.conversation.id)
        #expect(store.selectedTerminalID == tab.id)

        // Clicking it again shows the same tab.
        store.selectTerminal(nil)
        #expect(store.showRunningCLI(for: sandbox.conversation))
        #expect(store.selectedTerminalID == tab.id)
        #expect(store.terminalSessions.count == 1)
    }

    @Test func aSessionRunningInTmuxWhoseFolderIsMissingIsLeftToItsPreview() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.setTmuxSessionNames([TmuxSessionName.forConversation(sandbox.conversation)], on: .thisMac)
        try FileManager.default.removeItem(at: sandbox.project)

        #expect(!store.showRunningCLI(for: sandbox.conversation))
        #expect(store.terminalSessions.isEmpty)
    }
}

/// A project folder, a stand-in `claude` that exits right away, a session in the folder, and settings of its own.
@MainActor
private struct LaunchSandbox {
    let root: URL
    let project: URL
    let binaryDirectory: URL
    let conversation: Conversation
    let isolatedUserDefaults: IsolatedUserDefaults

    init() throws {
        root = try makeTemporaryDirectory()
        project = root.appendingPathComponent("project")
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nexit 0\n", to: binaryDirectory.appendingPathComponent("claude"))
        let sessionID = UUID().uuidString.lowercased()
        conversation = Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: project.path,
            suggestedTitle: "Sidebar by host",
            updatedAt: .now,
            sourceFile: project.appendingPathComponent("\(sessionID).jsonl")
        )
        isolatedUserDefaults = try IsolatedUserDefaults()
    }

    func makeStore() -> ConversationStore {
        ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
            commandResolver: NativeCLICommandResolver(searchDirectories: [binaryDirectory.path]),
            userDefaults: isolatedUserDefaults.userDefaults
        )
    }

    func tearDown() {
        isolatedUserDefaults.removeSuite()
        try? FileManager.default.removeItem(at: root)
    }
}
