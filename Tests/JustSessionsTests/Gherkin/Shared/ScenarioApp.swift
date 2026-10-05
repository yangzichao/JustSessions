import Foundation
import XCTest
@testable import JustSessions

/// The app one scenario runs: a store whose one adapter lists the sessions the scenario gives it, with files in a
/// temporary folder and settings in a suite of their own. Sessions are called by the title they were first listed with.
@MainActor
final class ScenarioApp {
    static let timeout: Duration = .seconds(10)

    let provider: ConversationProvider
    let store: ConversationStore
    let temporaryDirectory: URL
    private let adapter: ChangingConversationAdapter
    private let userDefaultsSuiteName: String
    private var sessionIDsByLabel: [String: String] = [:]

    init(provider: ConversationProvider) throws {
        self.provider = provider
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("gherkin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        adapter = ChangingConversationAdapter(provider: provider)
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

    var projectPath: String {
        temporaryDirectory.appendingPathComponent("project").path
    }

    /// Tabs never start their process here: no view shows them.
    var command: NativeCLICommand {
        NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: projectPath, environment: [])
    }

    func sessionID(labeled label: String) throws -> String {
        try XCTUnwrap(sessionIDsByLabel[label], "No session was given the title \"\(label)\"")
    }

    func listedConversation(labeled label: String) throws -> Conversation {
        let sessionID = try sessionID(labeled: label)
        return try XCTUnwrap(store.conversations.first { $0.sessionID == sessionID }, "\"\(label)\" is not listed")
    }

    func sidebarLists(_ title: String) -> Bool {
        store.conversations.contains { store.title(for: $0) == title }
    }

    /// A session a CLI is in that no file names yet, such as a thread Codex saves with its first prompt.
    @discardableResult
    func reserveSessionID(labeled label: String) -> String {
        let sessionID = makeSessionID()
        sessionIDsByLabel[label] = sessionID
        return sessionID
    }

    func listSession(labeled label: String, sessionID: String? = nil) async throws {
        let listedSessionID = addSessionWithoutListing(labeled: label, sessionID: sessionID)
        try await refreshUntilListed(listedSessionID)
    }

    /// The next refresh lists it. Without a `sessionID`, it keeps one reserved for `label`.
    @discardableResult
    func addSessionWithoutListing(labeled label: String, sessionID: String? = nil) -> String {
        let sessionID = sessionID ?? sessionIDsByLabel[label] ?? makeSessionID()
        sessionIDsByLabel[label] = sessionID
        adapter.add(Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: label,
            updatedAt: .now,
            sourceFile: temporaryDirectory.appendingPathComponent("\(sessionID).jsonl")
        ))
        return sessionID
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

    /// In the tool's own format; see `ConversationProvider.isValidSessionID`.
    private func makeSessionID() -> String {
        let uuid = UUID().uuidString.lowercased()
        return provider == .opencode ? "ses_" + uuid.replacingOccurrences(of: "-", with: "").prefix(26) : uuid
    }

    private func refreshUntilListed(_ sessionID: String) async throws {
        store.refreshThisMac()
        let isListed = try await eventually {
            !store.isScanningThisMac && store.conversations.contains { $0.sessionID == sessionID }
        }
        XCTAssertTrue(isListed, "The refresh did not list session \(sessionID)")
    }
}
