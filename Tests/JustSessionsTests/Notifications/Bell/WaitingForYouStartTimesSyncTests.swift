import Combine
import Foundation
import Testing

@testable import JustSessions

/// The activity sync times each wait for the bell, and publishes only when a wait starts or ends, so a window does
/// not redraw every second for a CLI that keeps waiting.
@MainActor
struct WaitingForYouStartTimesSyncTests {
    @Test func aSyncThatSeesTheSameWaitsDoesNotPublish() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = Conversation.fixture(provider: .claude, projectPath: directory.path, title: "Paper")
        // Finds no tmux, so the app's own tmux server is never asked.
        let store = ConversationStore(
            adapters: [],
            commandResolver: NativeCLICommandResolver(searchDirectories: [directory.path], inheritedEnvironment: [:]),
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
        store.replaceConversations(on: .thisMac, with: [conversation])
        // Stands in for the CLI in a tmux session whose tab closed.
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: StandInCLI.executablePath)
        cli.arguments = StandInCLI.arguments
        try cli.run()
        defer { if cli.isRunning { cli.terminate() } }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        store.tmuxSessionNamesByHost[.thisMac] = [tmuxSessionName]
        store.thisMacTmuxPaneProcessIDs[tmuxSessionName] = cli.processIdentifier
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))
        try FileManager.default.createDirectory(at: registry.sessionsDirectory, withIntermediateDirectories: true)
        try #"{"sessionId":"\#(conversation.sessionID)","status":"waiting","waitingFor":"input needed"}"#
            .write(
                to: registry.sessionsDirectory.appendingPathComponent("\(cli.processIdentifier).json"), atomically: true, encoding: .utf8)
        let publications = StoreChangeCounter(store) { _ = $0.waitingForYouStartTimes }
        defer { publications.cancel() }

        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(publications.count == 1)
        let entry = try #require(store.notificationBellEntries.first)
        #expect(entry.source == .detachedTmux(conversationID: conversation.id))
        #expect(entry.reason == .needsInput(reason: "input needed"))
        #expect(entry.sessionTitle == "Paper")

        await store.synchronizeCLIActivity(claudeRegistry: registry)
        await store.synchronizeCLIActivity(claudeRegistry: registry)
        #expect(publications.count == 1)
        #expect(store.notificationBellEntries.first?.waitingSince == entry.waitingSince)
    }
}
