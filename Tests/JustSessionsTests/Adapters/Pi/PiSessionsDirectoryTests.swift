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
}
