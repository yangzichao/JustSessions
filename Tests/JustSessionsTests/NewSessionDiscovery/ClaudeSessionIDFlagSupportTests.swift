import Foundation
import Testing
@testable import JustSessions

struct ClaudeSessionIDFlagSupportTests {
    private static let helpWithFlag = """
      -r, --resume [value]    Resume a conversation by session ID
      --session-id <uuid>     Use a specific session ID for the conversation (must be a valid UUID)
    """

    @Test func helpTextMustListTheFlagItself() {
        #expect(ClaudeSessionIDFlagSupport.helpTextListsFlag(Self.helpWithFlag))
        #expect(ClaudeSessionIDFlagSupport.helpTextListsFlag("  --session-id=<uuid>  Use a specific session ID"))
        #expect(!ClaudeSessionIDFlagSupport.helpTextListsFlag("  -r, --resume <session-id>  Resume a conversation"))
    }

    @Test func preassignsALowercaseSessionIDOnceHelpListsTheFlag() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\ncat <<'EOF'\n\(Self.helpWithFlag)\nEOF\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 5)

        #expect(support.check(command) == true)
        let preassignment = try #require(support.preassigningSessionID(to: command))

        #expect(preassignment.command.arguments == ["--session-id", preassignment.sessionID])
        #expect(preassignment.command.executablePath == command.executablePath)
        #expect(UUID(uuidString: preassignment.sessionID) != nil)
        #expect(preassignment.sessionID == preassignment.sessionID.lowercased())
    }

    @Test func launchesWithoutTheFlagWhenHelpDoesNotListIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\necho '  -r, --resume <session-id>  Resume'\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 5)

        #expect(support.check(command) == false)
        #expect(support.preassigningSessionID(to: command) == nil)
    }

    @Test func hungHelpLeavesTheAnswerOpenForALaterLaunch() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\nexec sleep 30\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 0.5)

        let startedAt = Date()
        #expect(support.check(command) == nil)
        #expect(Date().timeIntervalSince(startedAt) < 5)
    }

    @Test func uncheckedExecutableLaunchesWithoutTheFlagWhileItsCheckRuns() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\ncat <<'EOF'\n\(Self.helpWithFlag)\nEOF\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 5)

        #expect(support.preassigningSessionID(to: command) == nil)
        for _ in 0..<500 where support.preassigningSessionID(to: command) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(support.preassigningSessionID(to: command) != nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func fakeClaude(in root: URL, script: String) throws -> NativeCLICommand {
        let executable = root.appendingPathComponent("claude")
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return NativeCLICommand(
            executablePath: executable.path,
            arguments: [],
            workingDirectory: root.path,
            environment: ["PATH=/usr/bin:/bin"]
        )
    }
}
