import Foundation
import Testing
@testable import JustSessions

@MainActor
struct RemoteTmuxCommandOrderTests {
    /// A slow rename must not let the kill that follows it run first: the kill targets the new name, so it would find
    /// nothing, and the rename would then leave the CLI running under that name.
    @Test func endingASessionRightAfterItTookItsNameKillsItAfterTheRename() async throws {
        let recorder = RemoteCommandOrderRecorder()
        let runner = recorder.runner(delayingCommandsContaining: "rename-session", by: 0.3)
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        let conversation = Conversation.fixture(host: .ssh("devbox"))
        let tab = TerminalSession(
            conversation: conversation,
            provider: conversation.provider,
            projectPath: conversation.projectPath,
            action: .new,
            displayTitle: "New session",
            command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: []),
            host: .ssh("devbox"),
            tmuxSessionName: TmuxSessionName.unique(for: conversation.provider)
        )

        store.adoptSessionTmuxName(for: tab, remoteRunner: runner)
        let sessionName = try #require(tab.tmuxSessionName)
        store.endTmuxSession(named: sessionName, on: .ssh("devbox"), remoteRunner: runner)

        try await expectEventually { recorder.commands.count == 2 }
        #expect(recorder.commands.map { $0.contains("rename-session") ? "rename" : "kill" } == ["rename", "kill"])
    }
}

/// Stands in for `ssh`, recording each command when it finishes.
private final class RemoteCommandOrderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var finishedCommands: [String] = []

    var commands: [String] { lock.withLock { finishedCommands } }

    func runner(delayingCommandsContaining slowPart: String, by delay: TimeInterval) -> RemoteHostCommandRunner {
        RemoteHostCommandRunner { _, command, _ in
            if command.contains(slowPart) { Thread.sleep(forTimeInterval: delay) }
            self.lock.withLock { self.finishedCommands.append(command) }
            return (0, "")
        }
    }
}
