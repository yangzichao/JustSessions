import Foundation
import Testing
@testable import JustSessions

/// Saving a start command from the New session sheet keeps it only once it checks out.
@MainActor
struct SaveStartCommandTests {
    private static let keptCommand = "claude --dangerously-skip-permissions"

    /// Any program lookup on the host fails.
    private static let checkWithNothingInstalled = StartCommandCheck(
        resolver: NativeCLICommandResolver(searchDirectories: [], liveSessionReporting: nil),
        remoteRunner: RemoteHostCommandRunner { _, _, _ in (1, "") }
    )

    @Test func aCommandThatWouldNotStartKeepsTheOneBefore() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.setStartCommand(Self.keptCommand, for: .claude, on: .ssh("cloud"))

        await #expect(throws: StartCommandCheckError.missingProgram("~/.toolbox/bin/claud", host: .ssh("cloud"))) {
            try await store.saveStartCommand(
                "~/.toolbox/bin/claud --aws-profile dev", for: .claude, on: .ssh("cloud"), check: Self.checkWithNothingInstalled
            )
        }

        #expect(store.customStartCommand(for: .claude, on: .ssh("cloud")) == Self.keptCommand)
        #expect(CLIStartCommands.load(from: settings.userDefaults).customCommand(for: .claude, on: .ssh("cloud")) == Self.keptCommand)
    }

    @Test func goingBackToTheDefaultNeedsNoCheck() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.setStartCommand(Self.keptCommand, for: .claude, on: .ssh("cloud"))

        try await store.saveStartCommand("", for: .claude, on: .ssh("cloud"), check: Self.checkWithNothingInstalled)

        #expect(store.customStartCommand(for: .claude, on: .ssh("cloud")) == nil)
    }

    @Test func aCommandThatChecksOutIsKept() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = ConversationStore(adapters: [ClaudeAdapter()], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        let check = StartCommandCheck(
            resolver: NativeCLICommandResolver(searchDirectories: [], liveSessionReporting: nil),
            remoteRunner: RemoteHostCommandRunner { _, _, _ in (0, "") }
        )

        try await store.saveStartCommand("  \(Self.keptCommand)\n", for: .claude, on: .ssh("cloud"), check: check)

        #expect(CLIStartCommands.load(from: settings.userDefaults).customCommand(for: .claude, on: .ssh("cloud")) == Self.keptCommand)
    }
}
