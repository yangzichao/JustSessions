import Foundation
import XCTest
@testable import JustSessions

/// One Codex tab, with the Codex home in the app's temporary folder. The scenario sets the tab's terminal title as
/// the CLI would, and saves rollout files as Codex does.
@MainActor
final class CodexTabWorld: SessionTabWorld {
    let app: ScenarioApp
    private(set) var tab: TerminalSession?
    private let locator: CodexRolloutLocator

    init() throws {
        app = try ScenarioApp(provider: .codex)
        locator = CodexRolloutLocator(codexDirectory: app.temporaryDirectory)
    }

    func followTheCLIOnce() async {
        await app.store.followCodexThreads(locator: locator)
    }

    func openResumedTab(on label: String) throws {
        let conversation = try app.listedConversation(labeled: label)
        openTab(TerminalSession(
            conversation: conversation,
            provider: .codex,
            projectPath: app.projectPath,
            action: .resume,
            displayTitle: app.store.title(for: conversation),
            command: app.command,
            tmuxSessionName: TmuxSessionName.forConversation(conversation)
        ))
    }

    func openNewSessionTab() {
        openTab(TerminalSession(
            conversation: nil,
            provider: .codex,
            projectPath: app.projectPath,
            action: .new,
            displayTitle: ConversationProvider.codex.newSessionTabTitle,
            command: app.command,
            tmuxSessionName: TmuxSessionName.unique(for: .codex)
        ))
    }

    /// Writes the thread's rollout file where Codex does, under today, opening with its `session_meta` line. The next
    /// refresh lists the thread.
    func saveThread(labeled label: String) throws {
        let sessionID = app.addSessionWithoutListing(labeled: label)
        let now = Date.now
        let dayDirectory = app.temporaryDirectory.appendingPathComponent(
            "sessions/" + Self.formatted(now, as: "yyyy/MM/dd")
        )
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let sessionMeta = #"{"type":"session_meta","payload":{"id":"\#(sessionID)","cwd":"\#(app.projectPath)"}}"#
        try (sessionMeta + "\n").write(
            to: dayDirectory.appendingPathComponent("rollout-\(Self.formatted(now, as: "yyyy-MM-dd'T'HH-mm-ss"))-\(sessionID).jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Codex titles the terminal with the thread's id, cut to its first 29 characters and `...`.
    func cliMoves(toThreadLabeled label: String) async throws {
        let sessionID = try app.sessionID(labeled: label)
        await cliSetsTitle(String(sessionID.prefix(29)) + "...")
    }

    func cliSetsTitle(_ title: String) async {
        tab?.updateTerminalTitle(title)
        await followTheCLIOnce()
    }

    private func openTab(_ session: TerminalSession) {
        app.store.openTerminal(session)
        tab = session
    }

    private static func formatted(_ date: Date, as format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
