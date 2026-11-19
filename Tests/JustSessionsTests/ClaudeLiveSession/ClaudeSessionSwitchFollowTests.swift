import Foundation
import Testing

@testable import JustSessions

@Suite(.oneHeldThreadAtATime)
@MainActor
struct ClaudeSessionSwitchFollowTests {
    @Test func aBranchMadeWhileAnotherWindowScansIsFollowedOnceThatScanEnds() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let otherWindow = fixture.makeStore()
        defer { otherWindow.closeAllTerminals() }
        try await fixture.scan(with: otherWindow)
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        fixture.scans.holdNextScan()
        otherWindow.refreshThisMac()
        try await expectEventually { fixture.scans.scanCount == 3 }

        try fixture.transcripts.branch()
        fixture.synchronize()
        if fixture.store.isScanningThisMac {
            let joinDeadline = ContinuousClock.now + .seconds(120)
            while await fixture.readService.thisMacDiscoveryWaiterCount() < 2, ContinuousClock.now < joinDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        fixture.scans.releaseHeldScan()
        try await expectEventually { !fixture.store.isScanningThisMac && !otherWindow.isScanningThisMac }
        #expect(tab.conversation?.id == parent.id, "That scan read the folders before the branch")
        try await fixture.followTheCLI()

        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.branchTitle)
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.branchID) == ClaudeBranchCommandTranscripts.branchTitle)
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
    }

    @Test func aRenameWhileTheTabWaitsForTheBranchShowsOnTheTabAlone() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()

        try fixture.transcripts.branch()
        try fixture.transcripts.rename()
        fixture.synchronize()
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == "after-branch")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
        fixture.store.replaceConversations(on: .thisMac, with: fixture.store.conversations)
        #expect(tab.displayTitle == "after-branch")

        try await fixture.followTheCLI()
        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == "after-branch")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.branchID) == "after-branch")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
        let branch = try #require(fixture.store.conversations.first { $0.sessionID == ClaudeBranchCommandTranscripts.branchID })
        fixture.store.rename(branch, to: "Named in the app")
        fixture.synchronize()
        #expect(tab.displayTitle == "Named in the app")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.branchID) == "Named in the app")
    }

    @Test func renamingTheTabWhileItWaitsForTheBranchNamesTheBranch() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        try fixture.transcripts.branch()
        try fixture.transcripts.rename()
        fixture.synchronize()
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == "after-branch")

        let renamed = try #require(fixture.store.conversationToRename(fromTab: tab))
        #expect(fixture.store.title(for: renamed) == "after-branch", "The dialog opens on the name the tab shows")
        fixture.store.rename(renamed, to: "Mine")
        #expect(tab.displayTitle == "Mine")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
        fixture.synchronize()
        #expect(tab.displayTitle == "Mine", "A name given in the app wins")
        let reopened = try #require(fixture.store.conversationToRename(fromTab: tab))
        #expect(fixture.store.title(for: reopened) == "Mine", "It opens on that name the next time too")

        try await fixture.followTheCLI()
        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == "Mine")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.branchID) == "Mine")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
        let linked = try #require(fixture.store.conversationToRename(fromTab: tab))
        #expect(linked.id == tab.conversation?.id)
        #expect(fixture.store.title(for: linked) == "Mine")
    }

    @Test func commandDWhileTheTabWaitsForTheBranchBookmarksTheSessionItIsLinkedTo() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        try fixture.transcripts.branch()
        try fixture.transcripts.rename()
        fixture.synchronize()
        try #require(tab.displayTitle == "after-branch")

        let press = try #require(
            TerminalTabBookmarks(store: fixture.store, readingWindows: SessionReadingWindowManager())
                .toggleLatestMessage(in: tab))
        await press.value

        #expect(tab.conversation?.id == parent.id)
        guard case .added(let bookmark, _)? = tab.bookmarkNotices.notice else {
            Issue.record("Expected an added notice, got \(String(describing: tab.bookmarkNotices.notice))")
            return
        }
        #expect(fixture.store.messageBookmarks.bookmarks(forConversationID: parent.id) == [bookmark])
        #expect(Array(fixture.store.messageBookmarks.bookmarksByConversationID.keys) == [parent.id])
    }

    /// `/clear` keeps the name, and the new session may not be written until its first prompt. Until then a scan
    /// finds nothing more, so none runs; the first prompt's write asks for one, no sooner than a new session's tab
    /// refreshes this Mac, and the tab follows.
    @Test func clearFollowsTheNewSessionOnceItsFirstPromptIsWritten() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        try fixture.transcripts.append(
            to: parent.sessionID,
            [
                #"{"type":"custom-title","customTitle":"kept-name","sessionId":"\#(parent.sessionID)"}"#
            ])
        try fixture.transcripts.writeRecord(Self.record(sessionID: parent.sessionID, name: "kept-name"))
        fixture.synchronize()
        #expect(tab.displayTitle == "kept-name")

        let clearedID = UUID().uuidString.lowercased()
        try fixture.transcripts.writeRecord(Self.record(sessionID: clearedID, name: "kept-name"))
        try await fixture.followTheCLI()
        for _ in 1...3 { fixture.synchronize() }
        #expect(!fixture.store.isScanningThisMac && fixture.scans.scanCount == 2, "Nothing new to list")
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == "kept-name")

        try fixture.transcripts.append(
            to: clearedID,
            [
                #"{"type":"custom-title","customTitle":"kept-name","sessionId":"\#(clearedID)"}"#,
                #"{"parentUuid":null,"type":"user","message":{"role":"user","content":"After clear"},"uuid":"\#(UUID().uuidString.lowercased())","timestamp":"2026-10-21T20:00:00.000Z","cwd":"/Users/me/project","sessionId":"\#(clearedID)","version":"2.1.306"}"#,
            ])
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForAppearingSession - 1)
        fixture.synchronize()
        #expect(!fixture.store.isScanningThisMac && fixture.scans.scanCount == 2, "No sooner than a new session's tab")
        fixture.clock.advance(by: 1)
        try await fixture.followTheCLI()

        #expect(tab.conversation?.sessionID == clearedID)
        #expect(tab.displayTitle == "kept-name")
        #expect(fixture.title(of: clearedID) == "kept-name")
        #expect(fixture.title(of: ClaudeBranchCommandTranscripts.parentID) == "kept-name")
    }

    @Test func aTabWhoseCLIEndsWhileItWaitsNamesTheSessionItIsLinkedTo() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        try fixture.transcripts.branch()
        try fixture.transcripts.rename()
        fixture.scans.holdNextScan()
        fixture.synchronize()
        try await expectEventually { fixture.scans.scanCount == 2 }
        #expect(tab.displayTitle == "after-branch")

        tab.processFinished(exitCode: 0)
        fixture.synchronize()
        #expect(tab.unlistedClaudeSession == nil)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.parentTitle)

        fixture.scans.releaseHeldScan()
        try await fixture.followTheCLI()
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.parentTitle)
    }

    @Test func aResumedTabWhoseCLIStaysInItsSessionAsksForNoScan() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch()
        for _ in 1...3 { fixture.synchronize() }
        #expect(!fixture.store.isScanningThisMac && fixture.scans.scanCount == 1)

        try fixture.transcripts.writeRecord(Self.record(sessionID: parent.sessionID, name: "Renamed live"))
        fixture.synchronize()

        #expect(!fixture.store.isScanningThisMac && fixture.scans.scanCount == 1)
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == "Renamed live")
        #expect(fixture.title(of: parent.sessionID) == "Renamed live")
    }

    static func record(sessionID: String, name: String) -> String {
        #"{"pid":\#(ClaudeBranchCommandTranscripts.processID),"sessionId":"\#(sessionID)","kind":"interactive","name":"\#(name)","nameSource":"user","status":"idle"}"#
    }

    @MainActor
    private struct Fixture {
        let transcripts: ClaudeBranchCommandTranscripts
        let settings: IsolatedUserDefaults
        let scans: HoldableClaudeScans
        let readService: WorkspaceReadService
        let windows = WorkspaceWindowRegistry()
        let registry: ClaudeLiveSessionRegistry
        let store: ConversationStore
        let clock = StandInClock()

        init() throws {
            transcripts = try ClaudeBranchCommandTranscripts()
            settings = try IsolatedUserDefaults()
            scans = HoldableClaudeScans(configurationDirectory: transcripts.configurationDirectory)
            readService = WorkspaceReadService(
                adapters: [scans],
                commandResolver: NativeCLICommandResolver(
                    searchDirectories: [transcripts.root.path],
                    inheritedEnvironment: ["TMUX_TMPDIR": transcripts.root.path],
                    bundledTmuxDirectory: nil
                )
            )
            registry = ClaudeLiveSessionRegistry(configurationDirectory: transcripts.configurationDirectory)
            store = ConversationStore(
                userDefaults: settings.userDefaults,
                sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: windows,
                startsBackgroundPolling: false,
                readService: readService
            )
        }

        func makeStore() -> ConversationStore {
            ConversationStore(
                userDefaults: settings.userDefaults,
                sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: windows,
                startsBackgroundPolling: false,
                readService: readService
            )
        }

        func remove() {
            scans.releaseHeldScan()
            store.closeAllTerminals()
            settings.removeSuite()
            transcripts.remove()
        }

        func scan(with store: ConversationStore) async throws {
            store.refreshThisMac()
            try await expectEventually { !store.isScanningThisMac }
        }

        func openTabOnTheSessionToBranch() async throws -> (TerminalSession, Conversation) {
            try await scan(with: store)
            let parent = try #require(store.conversations.first { $0.sessionID == ClaudeBranchCommandTranscripts.parentID })
            let tab = TerminalSession(
                engine: .swiftTerm, conversation: parent, provider: .claude, projectPath: parent.projectPath,
                action: .resume, displayTitle: store.title(for: parent),
                command: NativeCLICommand(
                    executablePath: "/usr/bin/true", arguments: [], workingDirectory: transcripts.root.path, environment: []
                ),
                tmuxSessionName: TmuxSessionName.forConversation(parent)
            )
            tab.tmuxPaneProcessID = ClaudeBranchCommandTranscripts.processID
            store.openTerminal(tab)
            synchronize()
            return (tab, parent)
        }

        func synchronize() {
            store.synchronizeClaudeLiveNames(registry: registry, now: clock.now)
        }

        func followTheCLI() async throws {
            synchronize()
            try await expectEventually { !store.isScanningThisMac }
            synchronize()
        }

        func title(of sessionID: String) -> String? {
            store.conversations.first { $0.sessionID == sessionID }.map { store.title(for: $0) }
        }
    }
}
