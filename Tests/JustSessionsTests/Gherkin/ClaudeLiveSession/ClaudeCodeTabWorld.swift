import Foundation
import XCTest
@testable import JustSessions

/// One scenario's app: a store listing the sessions the scenario gives it, one Claude Code tab whose CLI runs in
/// tmux, and Claude Code's live registry in a temporary folder, which the scenario writes as the CLI would. Sessions
/// are called by the title they were first listed with.
@MainActor
final class ClaudeCodeTabWorld {
    static let cliProcessID: Int32 = 4242
    static let timeout: Duration = .seconds(10)

    let store: ConversationStore
    private(set) var tab: TerminalSession?
    private let adapter = ChangingConversationAdapter()
    private let temporaryDirectory: URL
    private let registry: ClaudeLiveSessionRegistry
    private let userDefaultsSuiteName: String
    private var sessionIDsByLabel: [String: String] = [:]
    /// What the live registry says about the tab's CLI: the session it is in, and the name it carries.
    private var cliSessionID = UUID().uuidString.lowercased()
    private var cliName: String?
    private var cliNameSource: String?

    init() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("gherkin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory.appendingPathComponent("sessions"),
            withIntermediateDirectories: true
        )
        registry = ClaudeLiveSessionRegistry(configurationDirectory: temporaryDirectory)
        let suiteName = "JustSessionsGherkin-\(UUID().uuidString)"
        userDefaultsSuiteName = suiteName
        // No tmux in reach, so a tab that follows its CLI never renames a session on the app's own tmux server.
        let commandResolver = NativeCLICommandResolver(
            searchDirectories: [temporaryDirectory.path],
            inheritedEnvironment: ["TMUX_TMPDIR": temporaryDirectory.path],
            bundledTmuxDirectory: nil
        )
        store = ConversationStore(
            adapters: [adapter],
            commandResolver: commandResolver,
            userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)),
            sessionNotifier: RecordingSessionNotifier(),
            startsBackgroundPolling: false
        )
    }

    func tearDown() {
        UserDefaults(suiteName: userDefaultsSuiteName)?.removePersistentDomain(forName: userDefaultsSuiteName)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    // MARK: Sessions

    func listSession(labeled label: String) async throws {
        writeSessionWithoutListing(labeled: label)
        try await refreshUntilListed(sessionID(labeled: label))
    }

    func writeSessionWithoutListing(labeled label: String) {
        let sessionID = UUID().uuidString.lowercased()
        sessionIDsByLabel[label] = sessionID
        adapter.add(conversation(sessionID: sessionID, title: label))
    }

    /// Lists the session the new tab's CLI is in under `title`, as its first prompt would.
    func listNewSession(as title: String) async throws {
        sessionIDsByLabel[title] = cliSessionID
        adapter.add(conversation(sessionID: cliSessionID, title: title))
        try await refreshUntilListed(cliSessionID)
    }

    func sessionID(labeled label: String) throws -> String {
        try XCTUnwrap(sessionIDsByLabel[label], "No session was given the title \"\(label)\"")
    }

    func sidebarLists(_ title: String) -> Bool {
        store.conversations.contains { store.title(for: $0) == title }
    }

    // MARK: The tab and its CLI

    func openResumedTab(on label: String) throws {
        let sessionID = try sessionID(labeled: label)
        let conversation = try XCTUnwrap(store.conversations.first { $0.sessionID == sessionID })
        cliSessionID = sessionID
        openTab(TerminalSession(
            conversation: conversation,
            provider: .claude,
            projectPath: projectPath,
            action: .resume,
            displayTitle: store.title(for: conversation),
            command: command,
            tmuxSessionName: TmuxSessionName.forConversation(conversation)
        ))
    }

    func openNewSessionTab() {
        openTab(TerminalSession(
            conversation: nil,
            provider: .claude,
            projectPath: projectPath,
            action: .new,
            displayTitle: "New Claude Code session",
            command: command,
            tmuxSessionName: TmuxSessionName.unique(for: .claude)
        ))
    }

    func cliChoosesName(_ name: String, source: String) throws {
        cliName = name
        cliNameSource = source
        try writeRegistryRecordAndSynchronize()
    }

    /// `/clear` moves the CLI to another session and keeps its name, as Claude Code does.
    func cliMoves(toSessionLabeled label: String) throws {
        cliSessionID = try sessionID(labeled: label)
        try writeRegistryRecordAndSynchronize()
    }

    /// Reads the registry as the app's live sync does every second, until `condition` holds or time runs out.
    func keepSynchronizing(until condition: () -> Bool) async throws -> Bool {
        try await eventually {
            store.synchronizeClaudeLiveNames(registry: registry)
            return condition()
        }
    }

    func eventually(_ condition: () -> Bool) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.timeout
        while !condition() {
            guard clock.now < deadline else { return false }
            try await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    // MARK: Private

    private var projectPath: String {
        temporaryDirectory.appendingPathComponent("project").path
    }

    private var command: NativeCLICommand {
        NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
    }

    private func openTab(_ session: TerminalSession) {
        // The tab's process is the tmux client; the registry is keyed by the CLI's own process, which tmux started.
        session.tmuxPaneProcessID = Self.cliProcessID
        store.openTerminal(session)
        tab = session
        try? writeRegistryRecord()
    }

    private func conversation(sessionID: String, title: String) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: .now,
            sourceFile: temporaryDirectory.appendingPathComponent("\(sessionID).jsonl")
        )
    }

    private func refreshUntilListed(_ sessionID: String) async throws {
        store.refreshThisMac()
        let isListed = try await eventually {
            !store.isScanningThisMac && store.conversations.contains { $0.sessionID == sessionID }
        }
        XCTAssertTrue(isListed, "The refresh did not list session \(sessionID)")
    }

    private func writeRegistryRecordAndSynchronize() throws {
        try writeRegistryRecord()
        store.synchronizeClaudeLiveNames(registry: registry)
    }

    private func writeRegistryRecord() throws {
        var record: [String: Any] = ["pid": Self.cliProcessID, "sessionId": cliSessionID]
        record["name"] = cliName
        record["nameSource"] = cliNameSource
        let data = try JSONSerialization.data(withJSONObject: record)
        try data.write(to: temporaryDirectory.appendingPathComponent("sessions/\(Self.cliProcessID).json"))
    }
}
