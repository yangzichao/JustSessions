import Foundation
import Testing
@testable import JustSessions

struct ClaudeSessionIDFlagSupportConcurrencyTests {
    /// Many tabs opening at once share one `--help` check, and once it answers each launch gets an id of its own.
    @Test func launchesAtTheSameTimeShareOneHelpCheck() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let helpRunsLog = root.appendingPathComponent("help-runs.log")
        let executable = try writeExecutableScript("""
            #!/bin/sh
            echo run >> '\(helpRunsLog.path)'
            sleep 0.2
            echo '  --session-id <uuid>  Use a specific session ID for the conversation'
            """, to: root.appendingPathComponent("claude"))
        let command = NativeCLICommand(
            executablePath: executable.path,
            arguments: [],
            workingDirectory: root.path,
            environment: ["PATH=/usr/bin:/bin"]
        )
        let support = ClaudeSessionIDFlagSupport(helpTimeout: 5)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask { _ = support.preassigningSessionID(to: command) }
            }
        }
        for _ in 0..<500 where support.preassigningSessionID(to: command) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let sessionIDs = (0..<20).compactMap { _ in support.preassigningSessionID(to: command)?.sessionID }

        #expect(sessionIDs.count == 20)
        #expect(Set(sessionIDs).count == 20)
        #expect(try String(contentsOf: helpRunsLog, encoding: .utf8) == "run\n")
    }
}
