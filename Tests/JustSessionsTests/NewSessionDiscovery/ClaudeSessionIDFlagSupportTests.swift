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

    @Test func aStartCommandIsCheckedWithItsOwnArguments() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let wrapper = try fakeClaude(
            in: root,
            script: "#!/bin/sh\nif [ \"$1\" = --new-cli ]; then echo '  --session-id <uuid>  Use a specific session ID'; fi\n"
        )
        let wrapperWithArgument = NativeCLICommand(
            executablePath: wrapper.executablePath,
            arguments: ["--new-cli"],
            workingDirectory: wrapper.workingDirectory,
            environment: wrapper.environment
        )
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 5)

        #expect(support.check(wrapper) == false)
        #expect(support.check(wrapperWithArgument) == true)
        #expect(support.preassigningSessionID(to: wrapper) == nil)
        let preassignment = try #require(support.preassigningSessionID(to: wrapperWithArgument))
        #expect(preassignment.command.arguments == ["--new-cli", "--session-id", preassignment.sessionID])
    }

    @Test func hungHelpLeavesTheAnswerOpenForALaterLaunch() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\nexec sleep 600\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 0.5)

        let startedAt = Date()
        #expect(support.check(command) == nil)
        #expect(Date().timeIntervalSince(startedAt) < 120)
    }

    @Test func uncheckedExecutableLaunchesWithoutTheFlagWhileItsCheckRuns() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let command = try fakeClaude(in: root, script: "#!/bin/sh\ncat <<'EOF'\n\(Self.helpWithFlag)\nEOF\n")
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 60)

        #expect(support.preassigningSessionID(to: command) == nil)
        try await expectEventually { support.preassigningSessionID(to: command) != nil }
    }

    private func fakeClaude(in root: URL, script: String) throws -> NativeCLICommand {
        let executable = root.appendingPathComponent("claude")
        try writeTimedStandIn(script, to: executable)
        return NativeCLICommand(
            executablePath: executable.path,
            arguments: [],
            workingDirectory: root.path,
            environment: ["PATH=/usr/bin:/bin"]
        )
    }
}
