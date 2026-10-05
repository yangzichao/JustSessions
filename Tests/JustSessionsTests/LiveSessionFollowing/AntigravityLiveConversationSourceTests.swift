import Foundation
import Testing
@testable import JustSessions

struct AntigravityLiveConversationSourceTests {
    @Test func theCLIIsInTheConversationItsLogNamedLast() throws {
        let configurationDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: configurationDirectory) }
        let logFile = try writeLog(AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.firstConversationID), in: configurationDirectory)
        let source = AntigravityLiveConversationSource(configurationDirectory: configurationDirectory) { _ in logFile }

        let session = try #require(source.currentSession(ofCLIProcessID: 4242))

        #expect(session.sessionID == AntigravityCLILogTests.firstConversationID)
        #expect(session.file == configurationDirectory.appendingPathComponent("conversations/\(AntigravityCLILogTests.firstConversationID).db"))
        #expect(source.currentSession(ofCLIProcessID: 0) == nil)
    }

    @Test func aConversationIsSavedOnceItsDatabaseNamesIt() throws {
        let configurationDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: configurationDirectory) }
        let source = AntigravityLiveConversationSource(configurationDirectory: configurationDirectory) { _ in nil }
        let conversationID = AntigravityCLILogTests.firstConversationID
        let session = LiveCLISession(
            sessionID: conversationID,
            file: configurationDirectory.appendingPathComponent("conversations/\(conversationID).db")
        )
        #expect(!source.isSaved(session))

        _ = try AntigravitySessionFixture(configurationDirectory: configurationDirectory, sessionID: conversationID)

        #expect(source.isSaved(session))
    }

    /// The log a running CLI holds open, as `lsof` lists it.
    @Test func findsTheLogTheCLIHoldsOpen() async throws {
        let configurationDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: configurationDirectory) }
        let logFile = try writeLog(AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.secondConversationID), in: configurationDirectory)
        let cli = Process()
        cli.executableURL = URL(fileURLWithPath: "/bin/sh")
        cli.arguments = ["-c", #"exec 3>>"$1"; exec sleep 30"#, "agy", logFile.path]
        try cli.run()
        defer { cli.terminate() }
        // The temporary folder is under /var, which `lsof` lists as /private/var.
        for _ in 0..<50 where !(ProcessOpenFileReader().openFilePaths(ofProcessIDs: [cli.processIdentifier])[cli.processIdentifier] ?? [])
            .contains(where: { $0.hasSuffix(logFile.lastPathComponent) }) {
            try await Task.sleep(for: .milliseconds(100))
        }
        let source = AntigravityLiveConversationSource(configurationDirectory: configurationDirectory)

        let session = source.currentSession(ofCLIProcessID: cli.processIdentifier)

        #expect(session?.sessionID == AntigravityCLILogTests.secondConversationID)
    }

    private func writeLog(_ text: String, in configurationDirectory: URL) throws -> URL {
        let logFile = configurationDirectory.appendingPathComponent("log/cli-20261004_155442.log")
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: logFile, atomically: true, encoding: .utf8)
        return logFile
    }
}
