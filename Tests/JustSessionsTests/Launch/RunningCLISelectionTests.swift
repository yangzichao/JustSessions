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

    /// As when an SSH host's connection drops, or the CLI quits: resuming starts the session again in its ended tab,
    /// in that tab's place, instead of opening a second tab of the session beside it.
    @Test func resumingASessionWhoseTabEndedStartsItAgainInThatTab() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let before = sandbox.openPlainTab(in: store)
        store.launch(sandbox.conversation, action: .resume)
        let endedTab = try #require(store.terminalSessions.last)
        let after = sandbox.openPlainTab(in: store)
        endedTab.processFinished(exitCode: 0)
        store.selectTerminal(after.id)

        store.launch(sandbox.conversation, action: .resume)

        let resumedTab = try #require(store.terminalSessions.first { $0.conversation?.id == sandbox.conversation.id })
        #expect(resumedTab.id != endedTab.id)
        #expect(!resumedTab.hasExited)
        #expect(store.terminalSessions.map(\.id) == [before.id, resumedTab.id, after.id])
        #expect(store.selectedTerminalID == resumedTab.id)
    }

    @Test func aSessionWhoseTabEndedInASplitStartsAgainInItsPlaceInTheSplit() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        let partner = sandbox.openPlainTab(in: store)
        store.launch(sandbox.conversation, action: .resume)
        let endedTab = try #require(store.terminalSessions.last)
        store.splitSelectedTerminal(with: partner.id)
        let split = try #require(store.shownSplit)
        let endedSide = try #require(store.sides(of: split)?.side(of: endedTab.id))
        endedTab.processFinished(exitCode: 0)

        store.launch(sandbox.conversation, action: .resume)

        #expect(store.terminalSessions.count == 2)
        let resumedTab = try #require(store.terminalSessions.first { $0.conversation?.id == sandbox.conversation.id })
        let resumedSplit = try #require(store.split(containing: resumedTab.id))
        #expect(resumedSplit.id == split.id)
        #expect(resumedSplit.contains(partner.id))
        #expect(store.sides(of: resumedSplit)?.side(of: resumedTab.id) == endedSide)
        expectSplitRules(store)
    }

    @Test func aSessionStillRunningInTmuxReattachesInItsEndedTab() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.launch(sandbox.conversation, action: .resume)
        let endedTab = try #require(store.terminalSessions.last)
        endedTab.processFinished(exitCode: 0)
        store.selectTerminal(nil)
        store.setTmuxSessionNames([TmuxSessionName.forConversation(sandbox.conversation)], on: .thisMac)

        #expect(store.showRunningCLI(for: sandbox.conversation))

        #expect(store.terminalSessions.count == 1)
        #expect(store.terminalSessions.first?.id != endedTab.id)
        #expect(store.selectedTerminalID == store.terminalSessions.first?.id)
    }

    /// A branch runs a new session of its own, so it still gets a tab of its own.
    @Test func branchingASessionWhoseTabEndedOpensANewTab() throws {
        let sandbox = try LaunchSandbox()
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        defer { store.closeAllTerminals() }
        store.launch(sandbox.conversation, action: .resume)
        let endedTab = try #require(store.terminalSessions.last)
        endedTab.processFinished(exitCode: 0)

        store.launch(sandbox.conversation, action: .branch)

        #expect(store.terminalSessions.count == 2)
        #expect(store.terminalSessions.contains { $0.id == endedTab.id })
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

    /// A plain terminal tab in the session's project, which starts nothing until it is shown.
    @discardableResult
    func openPlainTab(in store: ConversationStore) -> TerminalSession {
        let tab = TerminalSession(
            conversation: nil, provider: nil, projectPath: project.path, action: nil, displayTitle: "Terminal",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: project.path, environment: [])
        )
        store.openTerminal(tab)
        return tab
    }

    func tearDown() {
        isolatedUserDefaults.removeSuite()
        try? FileManager.default.removeItem(at: root)
    }
}
