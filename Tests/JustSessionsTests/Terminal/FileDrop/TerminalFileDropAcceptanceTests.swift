import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TerminalFileDropAcceptanceTests {
    @Test(arguments: TerminalEngine.allCases)
    func tabsOnThisMacTakeDroppedFiles(_ engine: TerminalEngine) {
        let cliTab = makeTab(engine: engine, provider: .claude, host: .thisMac)
        let plainTerminalTab = makeTab(engine: engine, provider: nil, host: .thisMac)

        #expect(cliTab.terminalView.registeredDraggedTypes.contains(.fileURL))
        #expect(plainTerminalTab.terminalView.registeredDraggedTypes.contains(.fileURL))
    }

    @Test(arguments: TerminalEngine.allCases)
    func tabsOnAnSSHHostTakeNoDroppedFiles(_ engine: TerminalEngine) {
        let sshTab = makeTab(engine: engine, provider: .codex, host: .ssh("devbox"))

        #expect(!sshTab.terminalView.acceptsDroppedFiles)
        #expect(sshTab.terminalView.registeredDraggedTypes.isEmpty)
    }

    @Test(arguments: TerminalEngine.allCases)
    func turningDropsOffUnregistersTheTerminal(_ engine: TerminalEngine) {
        var terminalView = engine.makeTabTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        terminalView.acceptsDroppedFiles = true
        terminalView.acceptsDroppedFiles = false

        #expect(terminalView.registeredDraggedTypes.isEmpty)
    }

    private func makeTab(engine: TerminalEngine, provider: ConversationProvider?, host: SessionHost) -> TerminalSession {
        TerminalSession(
            engine: engine,
            conversation: nil,
            provider: provider,
            projectPath: "/tmp/project",
            action: nil,
            displayTitle: "Tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host
        )
    }
}
