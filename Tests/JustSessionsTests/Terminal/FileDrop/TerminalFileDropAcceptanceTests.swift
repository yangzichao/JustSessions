import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TerminalFileDropAcceptanceTests {
    @Test func tabsOnThisMacTakeDroppedFiles() {
        let cliTab = makeTab(provider: .claude, host: .thisMac)
        let plainTerminalTab = makeTab(provider: nil, host: .thisMac)

        #expect(cliTab.terminalView.registeredDraggedTypes.contains(.fileURL))
        #expect(plainTerminalTab.terminalView.registeredDraggedTypes.contains(.fileURL))
    }

    @Test func tabsOnAnSSHHostTakeNoDroppedFiles() {
        let sshTab = makeTab(provider: .codex, host: .ssh("devbox"))

        #expect(!sshTab.terminalView.acceptsDroppedFiles)
        #expect(sshTab.terminalView.registeredDraggedTypes.isEmpty)
    }

    @Test func turningDropsOffUnregistersTheTerminal() {
        let terminalView = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        terminalView.acceptsDroppedFiles = true
        terminalView.acceptsDroppedFiles = false

        #expect(terminalView.registeredDraggedTypes.isEmpty)
    }

    private func makeTab(provider: ConversationProvider?, host: SessionHost) -> TerminalSession {
        TerminalSession(
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
