import Foundation
import Testing
@testable import JustSessions

struct PiSessionsDirectoryTests {
    @Test func defaultsToTheSessionsFolderInPisAgentFolder() {
        #expect(PiSessionsDirectory.standard(environment: [:], homeDirectory: "/Users/me").path == "/Users/me/.pi/agent/sessions")
        #expect(PiSessionsDirectory.standard(environment: ["PI_CODING_AGENT_DIR": "~/agents/pi"], homeDirectory: "/Users/me").path
            == "/Users/me/agents/pi/sessions")
    }

    @Test func environmentOverridesTheSettingsFileWhichOverridesTheDefault() throws {
        let agentDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: agentDirectory) }
        try #"{"sessionDir":"~/pi-sessions"}"#.write(
            to: agentDirectory.appendingPathComponent("settings.json"),
            atomically: true,
            encoding: .utf8
        )
        let fromSettings = PiSessionsDirectory.standard(
            environment: ["PI_CODING_AGENT_DIR": agentDirectory.path],
            homeDirectory: "/Users/me"
        )
        let fromEnvironment = PiSessionsDirectory.standard(
            environment: ["PI_CODING_AGENT_DIR": agentDirectory.path, "PI_CODING_AGENT_SESSION_DIR": "/srv/pi"],
            homeDirectory: "/Users/me"
        )

        #expect(fromSettings.path == "/Users/me/pi-sessions")
        #expect(fromEnvironment.path == "/srv/pi")
    }

    /// A mirrored SSH host can hold links and pipes named like sessions. Listing never opens a file, so a pipe that
    /// slipped through would only show up here, not hang the test.
    @Test func listsOnlyPlainSessionFiles() throws {
        let sessionsDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sessionsDirectory) }
        let projectDirectory = sessionsDirectory.appendingPathComponent("--Users-me-app--")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let elsewhere = sessionsDirectory.appendingPathComponent("elsewhere.txt")
        try "{}".write(to: elsewhere, atomically: true, encoding: .utf8)

        let plainFiles = [
            projectDirectory.appendingPathComponent("2026-10-01T00-00-00-000Z_019a0000-0000-7000-8000-000000000001.jsonl"),
            sessionsDirectory.appendingPathComponent("2026-10-01T00-00-00-000Z_019a0000-0000-7000-8000-000000000002.jsonl"),
        ]
        for file in plainFiles {
            try "{}".write(to: file, atomically: true, encoding: .utf8)
        }
        for directory in [projectDirectory, sessionsDirectory] {
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent("2026-10-01T00-00-00-000Z_019a0000-0000-7000-8000-0000000000a1.jsonl"),
                withDestinationURL: elsewhere
            )
            #expect(mkfifo(directory.appendingPathComponent("2026-10-01T00-00-00-000Z_019a0000-0000-7000-8000-0000000000b1.jsonl").path, 0o600) == 0)
        }

        let listed = PiSessionsDirectory.sessionFiles(in: sessionsDirectory).map(\.lastPathComponent).sorted()
        #expect(listed == plainFiles.map(\.lastPathComponent).sorted())
    }
}
