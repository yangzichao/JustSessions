import AppKit
import Foundation
import Testing
@testable import JustSessions

/// A private tmux server and a CLI that fails once, then stays running. Delayed commands reproduce a second Resume
/// reaching the app before cleanup of the first failed pane finished, without touching the app's tmux server.
@MainActor
@Suite(.serialized)
struct FailedCLIRestartOwnershipTests {
    @Test func repeatedResumeCannotKillTheReplacementCLI() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let failed = try await fixture.startFailedCLI()
        let beforeCleanup = RestartQueueGate(), afterCleanup = RestartQueueGate()
        defer { beforeCleanup.release(); afterCleanup.release() }
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { beforeCleanup.block() }
        try await expectEventually { beforeCleanup.hasStarted }
        fixture.store.launch(fixture.conversation, action: .resume)
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { afterCleanup.block() }
        fixture.store.launch(fixture.conversation, action: .resume)
        beforeCleanup.release()
        try await expectEventually { afterCleanup.hasStarted }
        try await expectEventually { fixture.store.terminalSessions.first?.id != failed.id }
        let replacement = try #require(fixture.store.terminalSessions.first)
        try await fixture.start(replacement)

        afterCleanup.release()
        await fixture.drainCommands()

        #expect(!replacement.hasExited)
        #expect(fixture.sandbox.server.paneProcessIDsBySessionName()[fixture.sessionName] != nil)
        #expect(fixture.store.terminalSessions.map(\.id) == [replacement.id])
    }

    @Test func closingAfterRepeatedResumeDoesNotReopenTheTabLater() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let failed = try await fixture.startFailedCLI()
        let gate = RestartQueueGate()
        defer { gate.release() }
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { gate.block() }
        try await expectEventually { gate.hasStarted }
        fixture.store.launch(fixture.conversation, action: .resume)
        fixture.store.launch(fixture.conversation, action: .resume)
        fixture.store.closeTerminal(failed.id)
        gate.release()
        await fixture.drainCommands()
        #expect(fixture.store.terminalSessions.isEmpty)
    }

    @Test func aResumeInAnotherWindowSelectsTheActualCleanupOwnerRatherThanAnOlderEndedTab() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let failed = try await fixture.startFailedCLI()
        let other = fixture.makeAnotherStore()
        defer { other.closeAllTerminals() }
        let older = TerminalSession(
            engine: .swiftTerm, conversation: fixture.conversation, provider: .claude,
            projectPath: fixture.sandbox.project.path, action: .resume, displayTitle: "Earlier ended tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [],
                                      workingDirectory: fixture.sandbox.project.path, environment: [])
        )
        older.processFinished(exitCode: 0)
        other.openTerminal(older)
        other.selectTerminal(nil)
        let gate = RestartQueueGate()
        defer { gate.release() }
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { gate.block() }
        try await expectEventually { gate.hasStarted }
        fixture.store.launch(fixture.conversation, action: .resume)

        other.launch(fixture.conversation, action: .resume)

        #expect(other.selectedTerminalID == nil)
        #expect(fixture.store.selectedTerminalID == failed.id)
        gate.release()
        await fixture.drainCommands()
        try await expectEventually { fixture.store.runningTerminal(for: fixture.conversation) != nil }
        let replacement = try #require(fixture.store.runningTerminal(for: fixture.conversation))
        #expect(replacement.id != failed.id)
        #expect(other.terminalSessions.map(\.id) == [older.id])
    }

    @Test(arguments: [false, true])
    func aResumeRequestedAfterCloseWaitsForOldCleanupInEitherWindow(_ inAnotherWindow: Bool) async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let failed = try await fixture.startFailedCLI()
        let target = inAnotherWindow ? fixture.makeAnotherStore() : fixture.store
        defer { if target !== fixture.store { target.closeAllTerminals() } }
        let gate = RestartQueueGate()
        defer { gate.release() }
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { gate.block() }
        try await expectEventually { gate.hasStarted }
        fixture.store.launch(fixture.conversation, action: .resume)
        fixture.store.closeTerminal(failed.id)

        target.launch(fixture.conversation, action: .resume)
        #expect(target.terminalSessions.isEmpty)
        gate.release()
        try await expectEventually { target.runningTerminal(for: fixture.conversation) != nil }
        let replacement = try #require(target.runningTerminal(for: fixture.conversation))
        try await fixture.start(replacement)
        await fixture.drainCommands()
        #expect(!replacement.hasExited)
        #expect(fixture.sandbox.server.paneProcessIDsBySessionName()[fixture.sessionName] != nil)
    }

    @Test func closingTheRequestersEndedTabCancelsADeferredResumeAfterTheCleanupOwnerClosed() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let failed = try await fixture.startFailedCLI()
        let other = fixture.makeAnotherStore()
        defer { other.closeAllTerminals() }
        let older = TerminalSession(
            engine: .swiftTerm, conversation: fixture.conversation, provider: .claude,
            projectPath: fixture.sandbox.project.path, action: .resume, displayTitle: "Earlier ended tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [],
                                      workingDirectory: fixture.sandbox.project.path, environment: [])
        )
        older.processFinished(exitCode: 0)
        other.openTerminal(older)
        let gate = RestartQueueGate()
        defer { gate.release() }
        fixture.store.tmuxCommandQueues.run(on: .thisMac) { gate.block() }
        try await expectEventually { gate.hasStarted }
        fixture.store.launch(fixture.conversation, action: .resume)
        fixture.store.closeTerminal(failed.id)

        other.launch(fixture.conversation, action: .resume)
        #expect(other.terminalSessions.map(\.id) == [older.id])
        other.closeTerminal(older.id)

        gate.release()
        await fixture.drainCommands()
        try await expectEventually { fixture.registry.terminalRestarts.tabBeingCleanedUp(for: fixture.conversation.id) == nil }
        #expect(fixture.store.terminalSessions.isEmpty)
        #expect(other.terminalSessions.isEmpty)
    }

    @MainActor
    private final class Fixture {
        let sandbox: ThisMacTmuxSandbox
        let settings: IsolatedUserDefaults
        let registry = WorkspaceWindowRegistry()
        let store: ConversationStore
        let conversation: Conversation
        let window: NSWindow
        var sessionName: String { TmuxSessionName.forConversation(conversation) }

        init() throws {
            sandbox = try #require(try ThisMacTmuxSandbox.make())
            settings = try IsolatedUserDefaults()
            try sandbox.writeExecutable(named: "claude", script: """
                #!/bin/sh
                if [ -e "$HOME/failed-once" ]; then echo CLI_RUNNING; exec /bin/sleep 600; fi
                /usr/bin/touch "$HOME/failed-once"
                echo INITIAL_FAILURE
                exit 2
                """)
            conversation = .fixture(projectPath: sandbox.project.path, sourceFile: sandbox.root.appendingPathComponent("session.jsonl"))
            store = ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
                commandResolver: sandbox.resolver, userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: registry, terminalEngineStore: try .pinned(to: .swiftTerm), startsBackgroundPolling: false
            )
            _ = NSApplication.shared
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
        }

        func makeAnotherStore() -> ConversationStore {
            let other = ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
                commandResolver: sandbox.resolver, userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(),
                windowRegistry: registry, startsBackgroundPolling: false
            )
            other.replaceConversations(on: .thisMac, with: [conversation])
            return other
        }

        func startFailedCLI() async throws -> TerminalSession {
            store.refreshThisMac()
            try await expectEventually { !self.store.isScanningThisMac }
            store.launch(conversation, action: .resume)
            let tab = try #require(store.terminalSessions.first)
            window.contentView = tab.terminalView
            tab.startIfNeeded()
            try await expectEventually { tab.hasExited }
            try #require(tab.tmuxSessionKeptForEndedCLI != nil)
            return tab
        }

        func start(_ tab: TerminalSession) async throws {
            window.contentView = tab.terminalView
            tab.startIfNeeded()
            try await expectEventually { screenText(of: tab.terminalView).contains("CLI_RUNNING") }
            try #require(sandbox.server.paneProcessIDsBySessionName()[sessionName] != nil)
        }

        func drainCommands() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.tmuxCommandQueues.run(on: .thisMac) { Task { @MainActor in continuation.resume() } }
            }
            for _ in 0..<5 { await Task.yield() }
        }

        func close() {
            store.closeAllTerminals()
            window.close()
            sandbox.tearDown()
            settings.removeSuite()
        }
    }
}

private final class RestartQueueGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var started = false
    var hasStarted: Bool { lock.withLock { started } }
    func block() { lock.withLock { started = true }; _ = semaphore.wait(timeout: .now() + 30) }
    func release() { semaphore.signal() }
}
