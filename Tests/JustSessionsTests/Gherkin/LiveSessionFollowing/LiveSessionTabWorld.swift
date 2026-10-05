import Foundation
import XCTest
@testable import JustSessions

/// One Antigravity, Pi, or OpenCode tab. Its CLI is a `ScenarioCLI`, whose process id the tab knows as a tmux pane's.
@MainActor
final class LiveSessionTabWorld: SessionTabWorld {
    static let cliProcessID: Int32 = 4242

    let app: ScenarioApp
    let cli: any ScenarioCLI
    private(set) var tab: TerminalSession?

    init(toolName: String) throws {
        let provider = try XCTUnwrap(
            [ConversationProvider.antigravity, .pi, .opencode].first { $0.rawValue == toolName },
            "No live session source for \(toolName)"
        )
        app = try ScenarioApp(provider: provider)
        let reporting = LiveSessionReporting(directory: app.temporaryDirectory.appendingPathComponent("reporting"))
        switch provider {
        case .pi:
            cli = ScenarioPiCLI(
                reporting: reporting,
                processID: Self.cliProcessID,
                sessionsDirectory: app.temporaryDirectory.appendingPathComponent("pi-sessions")
            )
        case .opencode:
            cli = ScenarioOpenCodeCLI(
                reporting: reporting,
                processID: Self.cliProcessID,
                database: try OpenCodeDatabaseFixture(file: app.temporaryDirectory.appendingPathComponent("opencode.db"))
            )
        default:
            cli = try ScenarioAntigravityCLI(temporaryDirectory: app.temporaryDirectory)
        }
    }

    func followTheCLIOnce() async {
        await app.store.followLiveSessions(sources: [cli.source])
    }

    func openResumedTab(on label: String) throws {
        let conversation = try app.listedConversation(labeled: label)
        openTab(TerminalSession(
            conversation: conversation,
            provider: app.provider,
            projectPath: app.projectPath,
            action: .resume,
            displayTitle: app.store.title(for: conversation),
            command: app.command,
            tmuxSessionName: TmuxSessionName.forConversation(conversation)
        ))
        try cli.moves(toSession: conversation.sessionID)
    }

    func openNewSessionTab() {
        openTab(TerminalSession(
            conversation: nil,
            provider: app.provider,
            projectPath: app.projectPath,
            action: .new,
            displayTitle: app.provider.newSessionTabTitle,
            command: app.command,
            tmuxSessionName: TmuxSessionName.unique(for: app.provider)
        ))
    }

    /// The tool saves the session where a refresh finds it, and the next refresh lists it.
    func saveSession(labeled label: String) throws {
        let sessionID = app.addSessionWithoutListing(labeled: label)
        try cli.saves(session: sessionID, projectPath: app.projectPath)
    }

    func cliMoves(toSessionLabeled label: String) async throws {
        try cli.moves(toSession: try app.sessionID(labeled: label))
        await followTheCLIOnce()
    }

    private func openTab(_ session: TerminalSession) {
        session.tmuxPaneProcessID = Self.cliProcessID
        app.store.openTerminal(session)
        tab = session
    }
}
