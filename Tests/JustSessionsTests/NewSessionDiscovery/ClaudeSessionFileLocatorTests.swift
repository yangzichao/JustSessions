import Foundation
import Testing
@testable import JustSessions

struct ClaudeSessionFileLocatorTests {
    private static let sessionID = "70b71200-8814-4822-a2e5-24abf31f7cbd"

    @Test func findsTheTranscriptInAnyProjectDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let otherProject = root.appendingPathComponent("projects/-Users-example-other")
        let project = root.appendingPathComponent("projects/-Users-example-project")
        try FileManager.default.createDirectory(at: otherProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let locator = ClaudeSessionFileLocator(configurationDirectory: root)

        #expect(locator.transcriptFile(forSessionID: Self.sessionID) == nil)

        let transcript = project.appendingPathComponent("\(Self.sessionID).jsonl")
        try "{}".write(to: transcript, atomically: true, encoding: .utf8)
        #expect(locator.transcriptFile(forSessionID: Self.sessionID)?.lastPathComponent == transcript.lastPathComponent)
        #expect(locator.transcriptFile(forSessionID: Self.sessionID)?.deletingLastPathComponent().lastPathComponent
            == "-Users-example-project")
    }

    @Test func rejectsInvalidSessionIDsAndMissingProjectsDirectory() {
        let missingRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let locator = ClaudeSessionFileLocator(configurationDirectory: missingRoot)

        #expect(locator.transcriptFile(forSessionID: Self.sessionID) == nil)
        #expect(locator.transcriptFile(forSessionID: "../escape") == nil)
    }
}
