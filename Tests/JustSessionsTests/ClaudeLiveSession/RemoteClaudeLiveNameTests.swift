import Foundation
import Testing

@testable import JustSessions

/// An SSH tab learns the Claude session and its chosen name from its title, never from this Mac's process registry.
@MainActor
struct RemoteClaudeLiveNameTests {
    @Test func aRemoteRenameUpdatesOnlyThatHostsTabAndRow() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let remote = Conversation.fixture(provider: .claude, sessionID: sessionID, title: "Remote prompt", host: .ssh("devbox"))
        let local = Conversation.fixture(provider: .claude, sessionID: sessionID, title: "Local prompt")
        let other = Conversation.fixture(provider: .claude, sessionID: sessionID, title: "Other prompt", host: .ssh("other"))
        fixture.store.replaceConversations(on: .thisMac, with: [local])
        fixture.store.replaceConversations(on: .ssh("other"), with: [other])
        fixture.store.replaceConversations(on: remote.host, with: [remote])
        let tab = fixture.openTab(remote)
        tab.updateTerminalTitle(try Self.title(sessionID: remote.sessionID, name: "Remote chosen name"))

        fixture.store.synchronizeClaudeLiveNames(registry: fixture.registry)

        #expect(tab.displayTitle == "Remote chosen name")
        #expect(fixture.title(of: remote) == "Remote chosen name")
        #expect(fixture.title(of: local) == "Local prompt")
        #expect(fixture.title(of: other) == "Other prompt")
    }

    @Test func theAppsNameWinsAndADerivedNameDoesNotRenameTheSession() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let remote = Conversation.fixture(provider: .claude, title: "First prompt", host: .ssh("devbox"))
        fixture.store.replaceConversations(on: remote.host, with: [remote])
        let tab = fixture.openTab(remote)
        tab.updateTerminalTitle(try Self.title(sessionID: remote.sessionID, name: "derived-name", source: "derived"))
        fixture.store.synchronizeClaudeLiveNames(registry: fixture.registry)
        #expect(tab.displayTitle == "First prompt")

        fixture.store.rename(remote, to: "My app name")
        tab.updateTerminalTitle(try Self.title(sessionID: remote.sessionID, name: "CLI name"))
        fixture.store.synchronizeClaudeLiveNames(registry: fixture.registry)
        #expect(tab.displayTitle == "My app name")
        #expect(fixture.title(of: remote) == "My app name")
    }

    @Test func clearFollowsTheRemoteSessionAndNamesOnlyTheNewOne() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let old = Conversation.fixture(provider: .claude, title: "Before clear", host: .ssh("devbox"))
        let new = Conversation.fixture(provider: .claude, title: "After clear", host: old.host)
        fixture.store.replaceConversations(on: old.host, with: [old, new])
        let tab = fixture.openTab(old)
        tab.updateTerminalTitle(try Self.title(sessionID: new.sessionID, name: "Continued name"))

        fixture.store.synchronizeClaudeLiveNames(registry: fixture.registry)

        #expect(tab.conversation?.id == new.id)
        #expect(tab.displayTitle == "Continued name")
        #expect(fixture.title(of: old) == "Before clear")
        #expect(fixture.title(of: new) == "Continued name")
    }

    /// Claude Code's `/branch` moves the CLI into a new session at once. A refresh of the host already under way read
    /// it before the branch was written, and drops a refresh asked for meanwhile, so the tab asks once it ends.
    /// Without that, the tab stays on the session it branched from, and `/rename` in the branch names neither until
    /// the host's next scheduled refresh, 5 minutes on.
    @Test func aBranchMadeWhileTheHostRefreshesIsFollowedOnceThatRefreshEnds() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        // The host's own refresh, as the auto refresh's, has read the host and is still copying.
        standIn.holdNextRefresh()
        fixture.store.refreshRemoteHost(standIn.host)
        try await expectEventually { standIn.refreshesThatReadTheHost == 2 }

        fixture.clock.advance(by: 1)
        try transcripts.branch()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .branched))
        fixture.synchronize()
        standIn.releaseHeldRefresh()
        try await fixture.waitForTheRefresh(of: standIn)
        #expect(fixture.title(ofSessionID: ClaudeBranchCommandTranscripts.branchID) == nil, "That refresh read the host before the branch")
        try await fixture.followTheCLI(on: standIn)

        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.branchTitle)
        try transcripts.rename()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .renamed))
        fixture.synchronize()
        #expect(tab.displayTitle == "after-branch")
        #expect(fixture.title(ofSessionID: ClaudeBranchCommandTranscripts.branchID) == "after-branch")
        #expect(fixture.title(of: parent) == ClaudeBranchCommandTranscripts.parentTitle)
    }

    /// A follow refresh that fails, as when the connection drops, is tried again as often as a new session's tab tries
    /// (SSH-66), counted from when it ended, not sooner, rather than leaving the tab until the host's auto refresh,
    /// which waits longer after each failure.
    @Test func aBranchWhoseRefreshFailsIsFollowedByTheNextTry() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)

        try transcripts.branch()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .branched))
        standIn.failNextRefreshes()
        try await fixture.followTheCLI(on: standIn)
        #expect(tab.conversation?.id == parent.id)
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession - 1)
        try await fixture.followTheCLI(on: standIn)
        #expect(standIn.refreshesThatReadTheHost == 2, "No sooner than a new session's tab")
        fixture.clock.advance(by: 1)
        try await fixture.followTheCLI(on: standIn)

        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.branchTitle)
        #expect(fixture.title(ofSessionID: ClaudeBranchCommandTranscripts.branchID) == ClaudeBranchCommandTranscripts.branchTitle)
        #expect(fixture.title(of: parent) == ClaudeBranchCommandTranscripts.parentTitle)
    }

    /// After `/clear`, Claude Code may write the new session only with its first prompt, so a copy of the host can end
    /// without listing it. The next copy waits 10 seconds from when that one ended, so a slow host isn't copied back
    /// to back, and comes only once the relay shows something new: an idle tab is left alone.
    @Test func aClearedTabCopiesItsHostAgainOnlyAfterAPauseAndOnceTheRelayChanges() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        let clearedID = UUID().uuidString.lowercased()
        tab.updateTerminalTitle(try Self.title(sessionID: clearedID, name: "kept-name"))
        // This copy takes 12 seconds, longer than the pause between copies.
        standIn.holdNextRefresh()
        fixture.synchronize()
        try await expectEventually { standIn.refreshesThatReadTheHost == 2 }
        fixture.clock.advance(by: 12)
        standIn.releaseHeldRefresh()
        try await fixture.waitForTheRefresh(of: standIn)

        fixture.synchronize()
        #expect(standIn.refreshesThatReadTheHost == 2, "Not straight after a copy ends")
        #expect(fixture.store.hostRefreshStatuses[.ssh(standIn.host)] != .refreshing)
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession)
        for _ in 1...3 { try await fixture.followTheCLI(on: standIn) }
        #expect(standIn.refreshesThatReadTheHost == 2, "The idle tab's relay shows nothing new")
        #expect(tab.conversation?.id == parent.id)
        #expect(tab.displayTitle == "kept-name")

        // The first prompt writes the session, and the relay shows the CLI at work.
        try transcripts.append(
            to: clearedID,
            [
                #"{"type":"custom-title","customTitle":"kept-name","sessionId":"\#(clearedID)"}"#,
                #"{"parentUuid":null,"type":"user","message":{"role":"user","content":"After clear"},"uuid":"\#(UUID().uuidString.lowercased())","timestamp":"2026-10-21T20:00:00.000Z","cwd":"/Users/me/project","sessionId":"\#(clearedID)","version":"2.1.306"}"#,
            ])
        tab.updateTerminalTitle(try Self.title(sessionID: clearedID, name: "kept-name", status: "busy"))
        try await fixture.followTheCLI(on: standIn)

        #expect(standIn.refreshesThatReadTheHost == 3)
        #expect(tab.conversation?.sessionID == clearedID)
        #expect(tab.displayTitle == "kept-name")
        #expect(fixture.title(ofSessionID: clearedID) == "kept-name")
    }

    /// Tabs waiting on one host, here in two windows, share its copies: one window's copy holds the other's back, and
    /// the next comes 10 seconds after it ended, whichever window asks.
    @Test func tabsWaitingOnOneHostInTwoWindowsShareItsCopies() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let otherSessionID = UUID().uuidString.lowercased()
        try transcripts.append(
            to: otherSessionID,
            [
                #"{"parentUuid":null,"type":"user","message":{"role":"user","content":"Other session"},"uuid":"\#(UUID().uuidString.lowercased())","timestamp":"2026-10-21T19:00:00.000Z","cwd":"/Users/me/project","sessionId":"\#(otherSessionID)","version":"2.1.306"}"#
            ])
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let otherWindow = fixture.makeWindow(listing: standIn)
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        try await expectEventually { otherWindow.conversations.contains { $0.sessionID == otherSessionID } }
        let other = try #require(otherWindow.conversations.first { $0.sessionID == otherSessionID })
        let otherTab = fixture.openTab(other, in: otherWindow)
        fixture.clock.advance(by: 1)

        let (clearedID, otherClearedID) = (UUID().uuidString.lowercased(), UUID().uuidString.lowercased())
        tab.updateTerminalTitle(try Self.title(sessionID: clearedID, name: "first"))
        otherTab.updateTerminalTitle(try Self.title(sessionID: otherClearedID, name: "second"))
        fixture.synchronize()
        fixture.synchronize(otherWindow)
        #expect(otherWindow.hostRefreshStatuses[.ssh(standIn.host)] != .refreshing, "The first window's copy is under way")
        try await fixture.waitForTheRefresh(of: standIn)
        fixture.synchronize(otherWindow)
        fixture.synchronize()
        #expect(standIn.refreshesThatReadTheHost == 2, "That copy started after both moves")

        // Both CLIs go on, so each relay shows something new.
        tab.updateTerminalTitle(try Self.title(sessionID: clearedID, name: "first", status: "busy"))
        otherTab.updateTerminalTitle(try Self.title(sessionID: otherClearedID, name: "second", status: "busy"))
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession - 1)
        fixture.synchronize(otherWindow)
        fixture.synchronize()
        #expect(standIn.refreshesThatReadTheHost == 2)
        fixture.clock.advance(by: 1)
        fixture.synchronize(otherWindow)
        fixture.synchronize()
        #expect(fixture.store.hostRefreshStatuses[.ssh(standIn.host)] != .refreshing, "The other window's copy is under way")
        try await fixture.waitForTheRefresh(of: standIn, in: otherWindow)
        try await fixture.waitForTheRefresh(of: standIn)
        fixture.synchronize()
        fixture.synchronize(otherWindow)
        #expect(standIn.refreshesThatReadTheHost == 3)
        #expect(tab.conversation?.id == parent.id)
        #expect(otherTab.conversation?.id == other.id)
    }

    /// A host whose copies keep failing, as when rsync is missing there or the mirror's disk is full, is tried every 10
    /// seconds three times, then as the auto refresh tries a failing host; one that waits for Connect… in any window,
    /// here another than the tab's, isn't tried.
    @Test func aHostThatKeepsFailingIsTriedLessOftenAndOneWaitingForConnectNotAtAll() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        try transcripts.branch()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .branched))
        standIn.failNextRefreshes(100)

        try await fixture.followTheCLI(on: standIn)
        for _ in 1..<ConversationStore.failedCopiesBeforeWaitingLonger {
            fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession)
            try await fixture.followTheCLI(on: standIn)
        }
        #expect(standIn.refreshesThatReadTheHost == 1 + ConversationStore.failedCopiesBeforeWaitingLonger)
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession)
        try await fixture.followTheCLI(on: standIn)
        #expect(standIn.refreshesThatReadTheHost == 1 + ConversationStore.failedCopiesBeforeWaitingLonger, "It waits longer now")
        fixture.clock.advance(by: HostAutoRefreshSchedule.wait(afterFailuresInARow: 1))
        try await fixture.followTheCLI(on: standIn)
        #expect(standIn.refreshesThatReadTheHost == 2 + ConversationStore.failedCopiesBeforeWaitingLonger, "As the auto refresh does")

        let otherWindow = fixture.makeWindow(listing: standIn)
        otherWindow.sshHostsNeedingLogIn.insert(standIn.host)
        standIn.failNextRefreshes(0)
        fixture.clock.advance(by: HostAutoRefreshSchedule.longestSSHHostWait)
        try await fixture.followTheCLI(on: standIn)
        #expect(standIn.refreshesThatReadTheHost == 2 + ConversationStore.failedCopiesBeforeWaitingLonger, "Connect… refreshes it")
        #expect(tab.conversation?.id == parent.id)
        otherWindow.sshHostsNeedingLogIn.remove(standIn.host)
        try await fixture.followTheCLI(on: standIn)
        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
    }

    /// After `ssh` couldn't reach a host, `SSHHostReachability` remembers it for a while, and a copy then fails at once
    /// without connecting. The tab copies nothing meanwhile, so only copies that tried the host count toward waiting
    /// longer, and once the memory ends, as when the network changes, the next copy follows the branch.
    @Test func aHostRememberedOutOfReachIsNotCopiedUntilThatEnds() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, parent) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        try transcripts.branch()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .branched))

        standIn.failNextRefreshes(as: .outOfReach)
        try await fixture.followTheCLI(on: standIn)
        #expect(SSHHostReachability.shared.recentFailureOutput(on: standIn.host) != nil)
        for _ in 1...ConversationStore.failedCopiesBeforeWaitingLonger {
            fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession)
            try await fixture.followTheCLI(on: standIn)
        }
        #expect(standIn.refreshesThatFailedWithoutConnecting == 0, "Each would fail at once")
        #expect(fixture.store.remoteHostCopies.copies(of: standIn.host).failuresInARow == 1)
        #expect(tab.conversation?.id == parent.id)

        // `SSHHostReachabilityResets` forgets it when the network changes or the Mac wakes; otherwise after a minute.
        SSHHostReachability.shared.forget(standIn.host)
        fixture.clock.advance(by: ConversationStore.refreshIntervalWhileWaitingForRemoteSession)
        try await fixture.followTheCLI(on: standIn)
        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.branchTitle)
    }

    /// A tab whose host is removed while it waits asks for nothing more.
    @Test func aTabWaitingOnARemovedHostStopsAsking() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let standIn = try fixture.standIn(forHostWith: transcripts)
        defer { standIn.remove() }
        let (tab, _) = try await fixture.openTabOnTheSessionToBranch(transcripts, on: standIn)
        try transcripts.branch()
        tab.updateTerminalTitle(try transcripts.relayTitle(at: .branched))
        standIn.failNextRefreshes()
        try await fixture.followTheCLI(on: standIn)
        let askedAt = try #require(tab.unlistedClaudeSession?.refreshRequestedAt)

        fixture.store.removeRemoteHost(
            standIn.host,
            mirror: RemoteSessionMirror(cacheRoot: fixture.directory.appendingPathComponent("mirrors"))
        )
        fixture.clock.advance(by: HostAutoRefreshSchedule.longestSSHHostWait)
        fixture.synchronize()

        #expect(tab.unlistedClaudeSession?.refreshRequestedAt == askedAt)
    }

    @Test func aRemoteTabNeverUsesALocalRegistryRecordWithTheSamePID() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let remote = Conversation.fixture(provider: .claude, title: "Remote prompt", host: .ssh("devbox"))
        fixture.store.replaceConversations(on: remote.host, with: [remote])
        let tab = fixture.openTab(remote)
        tab.tmuxSessionName = TmuxSessionName.forConversation(remote)
        tab.tmuxPaneProcessID = 4242
        let record = try JSONSerialization.data(withJSONObject: [
            "sessionId": remote.sessionID, "name": "Unrelated local name", "nameSource": "user",
        ])
        try record.write(to: fixture.registry.sessionsDirectory.appendingPathComponent("4242.json"))
        for title in ["✳ Remote prompt", "justsessions-activity:idle:", "justsessions-claude:not-base64"] {
            tab.updateTerminalTitle(title)
            fixture.store.synchronizeClaudeLiveNames(registry: fixture.registry)
            #expect(tab.displayTitle == "Remote prompt", "\(title)")
        }
    }

    /// Base64 keeps Unicode, JSON escapes, and terminal control characters out of the OSC title itself.
    static func title(sessionID: String, name: String, source: String = "user", status: String = "idle") throws -> String {
        let data = try JSONSerialization.data(withJSONObject: [
            "sessionId": sessionID, "name": name, "nameSource": source, "status": status,
        ])
        return "justsessions-claude:" + data.base64EncodedString() + ":"
    }

    @MainActor
    private struct Fixture {
        let directory: URL
        let registry: ClaudeLiveSessionRegistry
        let store: ConversationStore
        let settings: IsolatedUserDefaults
        let windows = WorkspaceWindowRegistry()
        /// The time the live name sync and the hosts' copies go by.
        let clock = StandInClock()

        init() throws {
            directory = try makeTemporaryDirectory()
            registry = ClaudeLiveSessionRegistry(configurationDirectory: directory)
            try FileManager.default.createDirectory(at: registry.sessionsDirectory, withIntermediateDirectories: true)
            settings = try IsolatedUserDefaults()
            store = ConversationStore(
                adapters: [],
                userDefaults: settings.userDefaults,
                windowRegistry: windows,
                remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }),
                startsBackgroundPolling: false
            )
            let clock = clock
            store.remoteHostCopies = RemoteHostCopies(currentDate: { clock.now })
        }

        /// The store lists the stand-in, and refreshes it as it would the host.
        func standIn(forHostWith transcripts: ClaudeBranchCommandTranscripts) throws -> ClaudeHostStandIn {
            let standIn = try ClaudeHostStandIn(home: transcripts.root, in: directory)
            store.remoteHostList = RemoteHostList(hosts: [standIn.host])
            store.remoteSessionDiscovery = standIn.discovery
            return standIn
        }

        /// Another window, which lists the stand-in as the first does and goes by the same clock.
        func makeWindow(listing standIn: ClaudeHostStandIn) -> ConversationStore {
            let window = ConversationStore(
                adapters: [],
                userDefaults: settings.userDefaults,
                windowRegistry: windows,
                remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }),
                startsBackgroundPolling: false
            )
            let clock = clock
            window.remoteHostCopies = RemoteHostCopies(currentDate: { clock.now })
            window.remoteHostList = RemoteHostList(hosts: [standIn.host])
            window.remoteSessionDiscovery = standIn.discovery
            return window
        }

        /// One beat of a window's live name sync.
        func synchronize(_ window: ConversationStore? = nil) {
            (window ?? store).synchronizeClaudeLiveNames(registry: registry, now: clock.now)
        }

        /// A tab on the session `/branch` is typed in, listed by a refresh of its host.
        func openTabOnTheSessionToBranch(
            _ transcripts: ClaudeBranchCommandTranscripts,
            on standIn: ClaudeHostStandIn
        ) async throws -> (TerminalSession, Conversation) {
            store.refreshRemoteHost(standIn.host)
            try await waitForTheRefresh(of: standIn)
            let parent = try #require(store.conversations.first { $0.sessionID == ClaudeBranchCommandTranscripts.parentID })
            let tab = openTab(parent)
            tab.updateTerminalTitle(try transcripts.relayTitle(at: .beforeBranch))
            synchronize()
            clock.advance(by: 1)
            return (tab, parent)
        }

        /// Waits for a window's refresh of the stand-in to end.
        func waitForTheRefresh(of standIn: ClaudeHostStandIn, in window: ConversationStore? = nil) async throws {
            let window = window ?? store
            try await expectEventually { window.hostRefreshStatuses[.ssh(standIn.host)] != .refreshing }
            standIn.forgetStatusLookupFailure()
        }

        /// One beat of the live name sync, which may ask for a refresh of the host, and the next once it ends.
        func followTheCLI(on standIn: ClaudeHostStandIn) async throws {
            synchronize()
            try await waitForTheRefresh(of: standIn)
            synchronize()
        }

        func title(ofSessionID sessionID: String) -> String? {
            store.conversations.first { $0.sessionID == sessionID }.map { store.title(for: $0) }
        }

        func remove() {
            for window in windows.stores { window.closeAllTerminals() }
            settings.removeSuite()
            try? FileManager.default.removeItem(at: directory)
        }

        func title(of conversation: Conversation) -> String? {
            store.conversations.first { $0.id == conversation.id }.map { store.title(for: $0) }
        }

        func openTab(_ conversation: Conversation, in window: ConversationStore? = nil) -> TerminalSession {
            let tab = TerminalSession(
                engine: .swiftTerm, conversation: conversation, provider: .claude, projectPath: conversation.projectPath,
                action: .resume, displayTitle: conversation.suggestedTitle,
                command: NativeCLICommand(
                    executablePath: StandInCLI.executablePath, arguments: StandInCLI.arguments,
                    workingDirectory: directory.path, environment: []
                ),
                host: conversation.host
            )
            (window ?? store).openTerminal(tab)
            return tab
        }
    }
}
