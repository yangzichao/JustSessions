import AppKit
import Testing

@testable import JustSessions

@MainActor
struct ThisMacTmuxFailedCLITests {
    @MainActor
    private struct Fixture {
        let sandbox: ThisMacTmuxSandbox
        let store: ConversationStore
        let conversation: Conversation
        let window: NSWindow
        var sessionName: String { TmuxSessionName.forConversation(conversation) }

        init?(cli script: String) throws {
            guard let sandbox = try ThisMacTmuxSandbox.make() else { return nil }
            self.sandbox = sandbox
            try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\n\(script)\n")
            conversation = Conversation(
                provider: .claude,
                sessionID: UUID().uuidString.lowercased(),
                projectPath: sandbox.project.path,
                suggestedTitle: "Paper",
                updatedAt: .now,
                sourceFile: sandbox.root.appendingPathComponent("session.jsonl")
            )
            store = ConversationStore(
                adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
                commandResolver: sandbox.resolver,
                // The screen it reads includes what scrolled off, which only SwiftTerm's API gives.
                terminalEngineStore: try .pinned(to: .swiftTerm),
                startsBackgroundPolling: false
            )
            _ = NSApplication.shared
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
        }

        func checkTmux() async throws {
            store.refreshThisMac()
            try #require(await sandbox.waitUntil { !store.isScanningThisMac })
        }

        func resume() async throws -> TerminalSession {
            let earlierTabID = store.terminalSessions.first?.id
            store.launch(conversation, action: .resume)
            try #require(await sandbox.waitUntil { store.terminalSessions.first.map { $0.id != earlierTabID } == true })
            let tab = try #require(store.terminalSessions.first)
            window.contentView = tab.terminalView
            tab.startIfNeeded()
            return tab
        }

        func screen(of tab: TerminalSession) -> String {
            screenText(of: tab.terminalView)
        }

        func tearDown() {
            store.closeAllTerminals()
            window.close()
            sandbox.tearDown()
        }
    }

    @Test func aFailedCLIKeepsItsOutputAndStatusUntilItsTabResumesIt() async throws {
        guard
            let fixture = try Fixture(
                cli: """
                    if [ -e "$HOME/failed-once" ]; then echo CLI_RUNNING; exec /bin/sleep 600; fi
                    /usr/bin/touch "$HOME/failed-once"
                    echo "error: unknown option --bogus" >&2
                    exit 2
                    """)
        else { return }
        defer { fixture.tearDown() }
        let sandbox = fixture.sandbox
        try await fixture.checkTmux()

        let failedTab = try await fixture.resume()

        try #require(await sandbox.waitUntil { failedTab.hasExited }, "\(sandbox.launchDiagnostics(for: failedTab))")
        #expect(failedTab.exitCode == 2)
        #expect(await sandbox.waitUntil { fixture.screen(of: failedTab).contains("error: unknown option --bogus") })
        #expect(sandbox.server.sessionNames() == [fixture.sessionName])
        #expect(sandbox.server.paneProcessIDsBySessionName().isEmpty)
        #expect(failedTab.tmuxSessionKeptForEndedCLI == fixture.sessionName)

        let resumedTab = try await fixture.resume()

        #expect(fixture.store.terminalSessions.map(\.id) == [resumedTab.id])
        #expect(
            await sandbox.waitUntil { fixture.screen(of: resumedTab).contains("CLI_RUNNING") },
            "\(sandbox.launchDiagnostics(for: resumedTab))")
        #expect(await sandbox.waitUntil { sandbox.server.paneProcessIDsBySessionName()[fixture.sessionName] != nil })
        #expect(!resumedTab.hasExited)
    }

    @Test func closingAFailedCLIsTabEndsItsSession() async throws {
        guard let fixture = try Fixture(cli: "echo 'error: not logged in' >&2\nexit 1") else { return }
        defer { fixture.tearDown() }
        let sandbox = fixture.sandbox
        try await fixture.checkTmux()
        let tab = try await fixture.resume()
        try #require(await sandbox.waitUntil { tab.hasExited }, "\(sandbox.launchDiagnostics(for: tab))")
        #expect(sandbox.server.sessionNames() == [fixture.sessionName])

        fixture.store.closeTerminal(tab.id)

        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
    }

    @Test func aCLIThatExitsCleanlyEndsItsSessionAsBefore() async throws {
        guard let fixture = try Fixture(cli: "echo done\nexit 0") else { return }
        defer { fixture.tearDown() }
        let sandbox = fixture.sandbox
        try await fixture.checkTmux()

        let tab = try await fixture.resume()

        try #require(await sandbox.waitUntil { tab.hasExited }, "\(sandbox.launchDiagnostics(for: tab))")
        #expect(tab.exitCode == 0)
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
        #expect(tab.tmuxSessionKeptForEndedCLI == nil)
    }

    @Test func aCLIThatFailsWithNoTabAttachedLeavesNoSession() async throws {
        guard let fixture = try Fixture(cli: "/bin/sleep 1\necho 'error: crashed' >&2\nexit 3") else { return }
        defer { fixture.tearDown() }
        let sandbox = fixture.sandbox
        try await fixture.checkTmux()
        let tab = try await fixture.resume()
        try #require(
            await sandbox.waitUntil { sandbox.server.sessionNames() == [fixture.sessionName] }, "\(sandbox.launchDiagnostics(for: tab))")

        fixture.store.closeTerminal(tab.id, endingTmuxSession: false)

        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
    }

    @Test func aCLIRunWithoutTmuxReportsTheStatusItExitedWith() async throws {
        guard let fixture = try Fixture(cli: "exit 2") else { return }
        defer { fixture.tearDown() }

        let tab = try await fixture.resume()

        try #require(await fixture.sandbox.waitUntil { tab.hasExited })
        #expect(tab.tmuxSessionName == nil)
        #expect(tab.exitCode == 2)
    }
}
