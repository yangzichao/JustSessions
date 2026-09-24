import Foundation
import Testing
@testable import JustSessions

struct ClaudeSessionFileLocatorTests {
    private static let sessionID = "70b71200-8814-4822-a2e5-24abf31f7cbd"

    @Test func findsTheTranscriptInAnyProjectDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let otherProject = root.appendingPathComponent("projects/-Users-example-other")
        let project = root.appendingPathComponent("projects/-Users-example-project")
        try FileManager.default.createDirectory(at: otherProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let locator = ClaudeSessionFileLocator(configurationDirectory: root)

        #expect(!locator.transcriptExists(forSessionID: Self.sessionID))

        try "{}".write(
            to: project.appendingPathComponent("\(Self.sessionID).jsonl"),
            atomically: true,
            encoding: .utf8
        )
        #expect(locator.transcriptExists(forSessionID: Self.sessionID))
    }

    @Test func rejectsInvalidSessionIDsAndMissingProjectsDirectory() {
        let missingRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let locator = ClaudeSessionFileLocator(configurationDirectory: missingRoot)

        #expect(!locator.transcriptExists(forSessionID: Self.sessionID))
        #expect(!locator.transcriptExists(forSessionID: "../escape"))
    }
}
