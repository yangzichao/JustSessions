import Foundation
import Testing
@testable import JustSessions

struct RemoteClaudeSessionIDFlagSupportTests {
    static let helpWithFlag = """
    bash: cannot set terminal process group (1234): Inappropriate ioctl for device
      -r, --resume [value]    Resume a conversation by session ID
      --session-id <uuid>     Use a specific session ID for the conversation (must be a valid UUID)
    """
    private static let helpWithoutFlag = "  -r, --resume [value]    Resume a conversation by session ID"

    @Test func runsTheHostsCLIOrTheStartCommandInItsLoginShell() {
        #expect(RemoteClaudeSessionIDFlagSupport.helpCommand(startCommand: nil)
            == RemoteCLICommandBuilder.loginShellCommand("claude --help"))
        #expect(RemoteClaudeSessionIDFlagSupport.helpCommand(startCommand: "  ")
            == RemoteCLICommandBuilder.loginShellCommand("claude --help"))
        #expect(RemoteClaudeSessionIDFlagSupport.helpCommand(startCommand: "~/bin/claude --model opus")
            == RemoteCLICommandBuilder.loginShellCommand("env ~/bin/claude --model opus '--help'"))
    }

    @Test func preassignsALowercaseSessionIDOnceTheHostsHelpListsTheFlag() throws {
        let recorder = RemoteCommandRecorder()
        let support = RemoteClaudeSessionIDFlagSupport(runner: recorder.runner(answering: (0, Self.helpWithFlag)))
        #expect(support.preassignedSessionID(host: "devbox", startCommand: nil) == nil)

        #expect(support.check(host: "devbox", startCommand: nil) == true)
        let sessionID = try #require(support.preassignedSessionID(host: "devbox", startCommand: nil))

        #expect(UUID(uuidString: sessionID) != nil)
        #expect(sessionID == sessionID.lowercased())
        #expect(support.preassignedSessionID(host: "devbox", startCommand: nil) != sessionID)
        #expect(support.preassignedSessionID(host: "laptop", startCommand: nil) == nil)
        #expect(recorder.commands.map(\.host) == ["devbox"])
    }

    @Test func launchesWithoutTheFlagWhenTheHostsHelpDoesNotListIt() {
        let support = RemoteClaudeSessionIDFlagSupport(runner: RemoteCommandRecorder().runner(answering: (0, Self.helpWithoutFlag)))
        #expect(support.check(host: "devbox", startCommand: nil) == false)
        #expect(support.preassignedSessionID(host: "devbox", startCommand: nil) == nil)
    }

    /// An offline host, a timeout, or a CLI that fails says nothing about the flag, so a later refresh asks again.
    @Test(arguments: [(Int32(255), ""), (Int32(127), "bash: claude: command not found"), (Int32(1), Self.helpWithFlag)])
    func anAnswerTheHostCouldNotGiveIsAskedAgain(exitStatus: Int32, output: String) async throws {
        let recorder = RemoteCommandRecorder()
        let support = RemoteClaudeSessionIDFlagSupport(runner: recorder.runner(answering: (exitStatus, output)))

        #expect(support.check(host: "devbox", startCommand: nil) == nil)
        #expect(support.preassignedSessionID(host: "devbox", startCommand: nil) == nil)
        support.checkInBackgroundIfUnanswered(host: "devbox", startCommand: nil)
        try await expectEventually(timeout: .seconds(10)) { recorder.commands.count == 2 }
    }

    @Test func timingOutIsAskedAgain() {
        let support = RemoteClaudeSessionIDFlagSupport(runner: RemoteCommandRecorder().runner(answering: nil))
        #expect(support.check(host: "devbox", startCommand: nil) == nil)
    }

    @Test func anAnsweredHostIsNotAskedAgain() async throws {
        let recorder = RemoteCommandRecorder()
        let support = RemoteClaudeSessionIDFlagSupport(runner: recorder.runner(answering: (0, Self.helpWithoutFlag)))

        support.checkInBackgroundIfUnanswered(host: "devbox", startCommand: nil)
        support.checkInBackgroundIfUnanswered(host: "devbox", startCommand: nil)
        try await expectEventually(timeout: .seconds(10)) { recorder.commands.count == 1 }
        try await Task.sleep(for: .milliseconds(200))
        support.checkInBackgroundIfUnanswered(host: "devbox", startCommand: nil)
        try await Task.sleep(for: .milliseconds(200))

        #expect(recorder.commands.count == 1)
    }

    /// A start command of your own can run another CLI, so it gets an answer of its own.
    @Test func aStartCommandHasAnAnswerOfItsOwn() {
        let support = RemoteClaudeSessionIDFlagSupport(runner: RemoteHostCommandRunner { _, command, _ in
            (0, command.contains("new-claude") ? Self.helpWithFlag : Self.helpWithoutFlag)
        })

        #expect(support.check(host: "devbox", startCommand: nil) == false)
        #expect(support.check(host: "devbox", startCommand: "~/bin/new-claude") == true)
        #expect(support.preassignedSessionID(host: "devbox", startCommand: nil) == nil)
        #expect(support.preassignedSessionID(host: "devbox", startCommand: "~/bin/new-claude") != nil)
        #expect(support.preassignedSessionID(host: "devbox", startCommand: "~/bin/new-claude --model opus") == nil)
    }
}
