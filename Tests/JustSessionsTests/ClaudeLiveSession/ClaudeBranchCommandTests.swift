import Foundation
import Testing
@testable import JustSessions

/// Claude Code's own `/branch`, typed in a running tab, moves the CLI into a new session; the tab follows it there,
/// and `/rename` names the branch, never the session it branched from. On SSH hosts, see `RemoteClaudeLiveNameTests`.
@MainActor
struct ClaudeBranchCommandTests {
    @Test func theTabFollowsTheBranchAndARenameThereNamesOnlyTheBranch() async throws {
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        // No tmux in reach, so following never renames a session on the app's own tmux server.
        let store = ConversationStore(
            adapters: [ClaudeAdapter(configurationDirectory: transcripts.configurationDirectory)],
            commandResolver: NativeCLICommandResolver(
                searchDirectories: [transcripts.root.path],
                inheritedEnvironment: ["TMUX_TMPDIR": transcripts.root.path],
                bundledTmuxDirectory: nil
            ),
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: transcripts.configurationDirectory)
        let readers = AppendedSessionNameReaders()
        func followTheCLI() async throws {
            store.synchronizeClaudeLiveNames(registry: registry)
            await store.followAppendedSessionNames(readers: readers, codexDirectory: transcripts.root)
            try await expectEventually { !store.isScanningThisMac }
        }
        func title(of sessionID: String) -> String? {
            store.conversations.first { $0.sessionID == sessionID }.map { store.title(for: $0) }
        }
        store.refreshThisMac()
        try await expectEventually { !store.isScanningThisMac }
        let parent = try #require(store.conversations.first { $0.sessionID == ClaudeBranchCommandTranscripts.parentID })
        let tab = TerminalSession(
            engine: .swiftTerm, conversation: parent, provider: .claude, projectPath: parent.projectPath, action: .resume,
            displayTitle: store.title(for: parent),
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: transcripts.root.path, environment: []),
            tmuxSessionName: TmuxSessionName.forConversation(parent)
        )
        tab.tmuxPaneProcessID = ClaudeBranchCommandTranscripts.processID
        store.openTerminal(tab)
        try await followTheCLI()

        try transcripts.branch()
        try await followTheCLI()
        try await followTheCLI()
        #expect(tab.conversation?.sessionID == ClaudeBranchCommandTranscripts.branchID)
        #expect(tab.displayTitle == ClaudeBranchCommandTranscripts.branchTitle)
        #expect(title(of: ClaudeBranchCommandTranscripts.branchID) == ClaudeBranchCommandTranscripts.branchTitle)

        try transcripts.rename()
        try await followTheCLI()
        #expect(tab.displayTitle == "after-branch")
        #expect(title(of: ClaudeBranchCommandTranscripts.branchID) == "after-branch")
        #expect(title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)

        store.refreshThisMac()
        try await followTheCLI()
        #expect(tab.displayTitle == "after-branch")
        #expect(title(of: ClaudeBranchCommandTranscripts.branchID) == "after-branch")
        #expect(title(of: ClaudeBranchCommandTranscripts.parentID) == ClaudeBranchCommandTranscripts.parentTitle)
    }

    /// The branch's copied lines keep the uuids, timestamps, and a `session_id` of the session it branched from, and
    /// name it in `forkedFrom`; each file is still a session of its own, titled by its own latest custom-title.
    @Test func theBranchIsListedApartFromTheSessionItBranchedFrom() throws {
        let transcripts = try ClaudeBranchCommandTranscripts()
        defer { transcripts.remove() }
        try transcripts.branch()
        try transcripts.rename()

        let titles = Dictionary(uniqueKeysWithValues: try transcripts.listed().map { ($0.sessionID, $0.suggestedTitle) })

        #expect(titles == [
            ClaudeBranchCommandTranscripts.parentID: ClaudeBranchCommandTranscripts.parentTitle,
            ClaudeBranchCommandTranscripts.branchID: "after-branch",
        ])
    }
}
