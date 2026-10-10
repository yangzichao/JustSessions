import Foundation
import XCTest
@testable import JustSessions

/// One Claude Code, Pi, or Codex tab whose CLI appends names to a file in the app's temporary folder, as the tool does:
/// the session's own file, or Codex's `session_index.jsonl`.
@MainActor
final class AppendedSessionNameWorld: SessionTabWorld {
    let app: ScenarioApp
    private(set) var tab: TerminalSession?
    private let readers = AppendedSessionNameReaders()
    private let codexDirectory: URL

    init(toolName: String) throws {
        let provider = try XCTUnwrap(
            ["Claude": ConversationProvider.claude, "Pi": .pi, "Codex": .codex][toolName],
            "\(toolName) appends no names to follow"
        )
        app = try ScenarioApp(provider: provider)
        codexDirectory = app.temporaryDirectory.appendingPathComponent("codex")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
    }

    func followTheCLIOnce() async {
        app.store.followAppendedSessionNames(readers: readers, codexDirectory: codexDirectory)
    }

    /// The tab opens on a listed session whose file exists, and the app takes its first look at that file.
    func openTab(on label: String) async throws {
        try await app.listSession(labeled: label)
        let conversation = try app.listedConversation(labeled: label)
        let file = try nameFile(for: conversation)
        if !FileManager.default.fileExists(atPath: file.path) { try Data().write(to: file) }
        let session = TerminalSession(
            engine: .swiftTerm,
            conversation: conversation,
            provider: app.provider,
            projectPath: app.projectPath,
            action: .resume,
            displayTitle: app.store.title(for: conversation),
            command: app.command,
            tmuxSessionName: TmuxSessionName.forConversation(conversation)
        )
        app.store.openTerminal(session)
        tab = session
        await followTheCLIOnce()
    }

    func renameInApp(_ name: String) throws {
        let conversation = try XCTUnwrap(tab?.conversation)
        app.store.rename(conversation, to: name)
    }

    /// Appends the line the tool writes for `name`, for the tab's session or `sessionID`, then follows once.
    func cliAppendsName(_ name: String, forSessionID sessionID: String? = nil) async throws {
        let conversation = try XCTUnwrap(tab?.conversation)
        let record: [String: Any] = switch app.provider {
        case .claude: ["type": "custom-title", "customTitle": name, "sessionId": conversation.sessionID]
        case .pi: ["type": "session_info", "name": name]
        default: ["id": sessionID ?? conversation.sessionID, "thread_name": name, "updated_at": "2026-10-05T00:00:00Z"]
        }
        let handle = try FileHandle(forWritingTo: nameFile(for: conversation))
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: JSONSerialization.data(withJSONObject: record) + Data("\n".utf8))
        await followTheCLIOnce()
    }

    private func nameFile(for conversation: Conversation) throws -> URL {
        try XCTUnwrap(AppendedSessionNameSource.file(for: conversation, codexDirectory: codexDirectory))
    }
}
