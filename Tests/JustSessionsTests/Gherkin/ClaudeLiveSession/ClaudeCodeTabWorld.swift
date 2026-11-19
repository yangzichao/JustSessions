import Foundation
import XCTest

@testable import JustSessions

@MainActor
final class ClaudeCodeTabWorld: SessionTabWorld {
    static let cliProcessID: Int32 = 4242

    let app: ScenarioApp
    private(set) var tab: TerminalSession?
    private let registry: ClaudeLiveSessionRegistry
    private var cliSessionID = UUID().uuidString.lowercased()
    private var cliName: String?
    private var cliNameSource: String?

    init() throws {
        app = try ScenarioApp(provider: .claude)
        try FileManager.default.createDirectory(
            at: app.temporaryDirectory.appendingPathComponent("sessions"),
            withIntermediateDirectories: true
        )
        registry = ClaudeLiveSessionRegistry(configurationDirectory: app.temporaryDirectory)
    }

    func followTheCLIOnce() async {
        app.store.synchronizeClaudeLiveNames(registry: registry)
    }

    func listNewSession(as title: String) async throws {
        try await app.listSession(labeled: title, sessionID: cliSessionID)
    }

    func openResumedTab(on label: String) throws {
        let conversation = try app.listedConversation(labeled: label)
        cliSessionID = conversation.sessionID
        openTab(
            TerminalSession(
                engine: .swiftTerm,
                conversation: conversation,
                provider: .claude,
                projectPath: app.projectPath,
                action: .resume,
                displayTitle: app.store.title(for: conversation),
                command: app.command,
                tmuxSessionName: TmuxSessionName.forConversation(conversation)
            ))
    }

    func openNewSessionTab() {
        openTab(
            TerminalSession(
                engine: .swiftTerm,
                conversation: nil,
                provider: .claude,
                projectPath: app.projectPath,
                action: .new,
                displayTitle: "New Claude Code session",
                command: app.command,
                tmuxSessionName: TmuxSessionName.unique(for: .claude)
            ))
    }

    func cliChoosesName(_ name: String, source: String) throws {
        cliName = name
        cliNameSource = source
        try writeRegistryRecordAndSynchronize()
    }

    func cliMoves(toSessionLabeled label: String) throws {
        cliSessionID = try app.sessionID(labeled: label)
        try writeRegistryRecordAndSynchronize()
    }

    private func openTab(_ session: TerminalSession) {
        // The tab's process is the tmux client; the registry is keyed by the CLI's own process, which tmux started.
        session.tmuxPaneProcessID = Self.cliProcessID
        app.store.openTerminal(session)
        tab = session
        try? writeRegistryRecord()
    }

    private func writeRegistryRecordAndSynchronize() throws {
        try writeRegistryRecord()
        app.store.synchronizeClaudeLiveNames(registry: registry)
    }

    private func writeRegistryRecord() throws {
        var record: [String: Any] = ["pid": Self.cliProcessID, "sessionId": cliSessionID]
        record["name"] = cliName
        record["nameSource"] = cliNameSource
        let data = try JSONSerialization.data(withJSONObject: record)
        try data.write(to: app.temporaryDirectory.appendingPathComponent("sessions/\(Self.cliProcessID).json"))
    }
}
