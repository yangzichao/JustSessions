import Foundation
import Testing
@testable import JustSessions

struct AntigravityCLILogTailTests {
    @Test func picksUpTheConversationsTheGrowingLogNames() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let logFile = directory.appendingPathComponent("cli-20261004_155442.log")
        try "I1004 15:54:42.450497      69 server.go:1612] Starting language server process\n"
            .write(to: logFile, atomically: true, encoding: .utf8)
        var tail = AntigravityCLILogTail()

        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == nil)

        try append(AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.firstConversationID), to: logFile)
        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == AntigravityCLILogTests.firstConversationID)

        try append("I1004 15:55:46.195270    1209 server.go:1840] Sending user message\n", to: logFile)
        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == AntigravityCLILogTests.firstConversationID)

        try append(AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.secondConversationID), to: logFile)
        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == AntigravityCLILogTests.secondConversationID)
    }

    @Test func readsALineOnlyOnceItIsComplete() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let logFile = directory.appendingPathComponent("cli-20261004_155442.log")
        let streamLine = AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.firstConversationID)
        let halfLine = String(streamLine.prefix(streamLine.count - 20))
        try halfLine.write(to: logFile, atomically: true, encoding: .utf8)
        var tail = AntigravityCLILogTail()

        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == nil)

        try append(String(streamLine.dropFirst(halfLine.count)), to: logFile)
        tail.readNewLines(of: logFile)
        #expect(tail.conversationID == AntigravityCLILogTests.firstConversationID)
    }

    @Test func aLogThatWasCutShortIsReadFromTheStart() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let logFile = directory.appendingPathComponent("cli-20261004_155442.log")
        try (String(repeating: "I1004 15:54:42.450497      69 server.go:1612] Padding\n", count: 20)
            + AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.firstConversationID))
            .write(to: logFile, atomically: true, encoding: .utf8)
        var tail = AntigravityCLILogTail()
        tail.readNewLines(of: logFile)

        try AntigravityCLILogTests.streamLine(for: AntigravityCLILogTests.secondConversationID)
            .write(to: logFile, atomically: true, encoding: .utf8)
        tail.readNewLines(of: logFile)

        #expect(tail.conversationID == AntigravityCLILogTests.secondConversationID)
    }

    private func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }
}
