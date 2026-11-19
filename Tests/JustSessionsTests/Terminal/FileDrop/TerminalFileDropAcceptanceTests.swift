import AppKit
import Testing

@testable import JustSessions

@MainActor
struct TerminalFileDropAcceptanceTests {
    @Test(arguments: TerminalEngine.allCases)
    func tabsOnThisMacTypeDroppedFilesPaths(_ engine: TerminalEngine) {
        let cliTab = makeTab(engine: engine, provider: .claude, host: .thisMac)
        let plainTerminalTab = makeTab(engine: engine, provider: nil, host: .thisMac)

        for tab in [cliTab, plainTerminalTab] {
            #expect(tab.terminalView.registeredDraggedTypes.contains(.fileURL))
            #expect(tab.terminalView.copyDroppedFilesToHost == nil)
            #expect(tab.sshFileDrop == nil)
        }
    }

    @Test(arguments: TerminalEngine.allCases)
    func tabsOnAnSSHHostCopyDroppedFilesThereFirst(_ engine: TerminalEngine) {
        let cliTab = makeTab(engine: engine, provider: .codex, host: .ssh("devbox"))
        let plainTerminalTab = makeTab(engine: engine, provider: nil, host: .ssh("devbox"))

        for tab in [cliTab, plainTerminalTab] {
            #expect(tab.terminalView.registeredDraggedTypes.contains(.fileURL))
            #expect(tab.terminalView.copyDroppedFilesToHost != nil)
            #expect(tab.sshFileDrop?.host == "devbox")
        }
    }

    @Test(arguments: TerminalEngine.allCases)
    func anSSHTabWaitingToBeShownTakesNoFiles(_ engine: TerminalEngine) throws {
        let tab = makeTab(engine: engine, provider: .codex, host: .ssh("devbox"), startsOnceShown: true)
        let copyDroppedFilesToHost = try #require(tab.terminalView.copyDroppedFilesToHost)

        #expect(!copyDroppedFilesToHost([URL(fileURLWithPath: "/tmp/shot.png")]))
        #expect(tab.sshFileDrop?.isCopying == false)
    }

    @Test(arguments: TerminalEngine.allCases)
    func turningDropsOffUnregistersTheTerminal(_ engine: TerminalEngine) {
        var terminalView = engine.makeTabTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        terminalView.acceptsDroppedFiles = true
        terminalView.acceptsDroppedFiles = false

        #expect(terminalView.registeredDraggedTypes.isEmpty)
    }

    private func makeTab(
        engine: TerminalEngine,
        provider: ConversationProvider?,
        host: SessionHost,
        startsOnceShown: Bool = false
    ) -> TerminalSession {
        TerminalSession(
            engine: engine,
            conversation: nil,
            provider: provider,
            projectPath: "/tmp/project",
            action: nil,
            displayTitle: "Tab",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: host,
            startsOnceShown: startsOnceShown
        )
    }
}
