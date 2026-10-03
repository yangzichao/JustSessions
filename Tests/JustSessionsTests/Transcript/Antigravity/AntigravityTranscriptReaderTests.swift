import Foundation
import Testing
@testable import JustSessions

struct AntigravityTranscriptReaderTests {
    @Test func readsVisibleMessagesAndToolCallsWhileHidingThinkingAndInjectedContext() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        let field = AntigravitySessionFixture.field
        let tool = field(2, Data("run_command".utf8)) + field(3, Data(#"{"command":"swift build"}"#.utf8))
        let response = field(1, Data("Build succeeded".utf8)) + field(3, Data("Private thinking".utf8)) + field(7, tool)
        try fixture.append(field(20, response), type: 15, index: 1)
        try fixture.appendPrompt("Internal context", index: 2, source: 2)
        try fixture.appendPrompt("Cleared prompt", index: 3, status: 5)
        try fixture.append(field(114, Data("Raw tool output".utf8)), type: 101, index: 4)
        try fixture.append(Data([0xff, 0xff]), type: 15, index: 5)

        let transcript = try await TranscriptLoader.load(fixture.conversation)
        #expect(transcript.entries.map(\.content) == [.userMessage("Fix the build"), .assistantMessage("Build succeeded"), .toolCalls(["run_command · swift build"])])
        #expect(transcript.entries.first?.timestamp == Date(timeIntervalSince1970: 1_790_400_000.25))
    }

    @Test func limitsLongMessagesAndKeepsTheNewestEntries() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try AntigravitySessionFixture(configurationDirectory: root)
        for index in 1...4 { try fixture.appendPrompt("Prompt \(index) " + String(repeating: "界", count: 30), index: index) }
        let transcript = try AntigravityTranscriptReader(maximumEntryCount: 2, maximumTextLength: 10).read(fixture.databaseFile)
        #expect(transcript.entries.count == 2)
        #expect(transcript.omittedEntryCount == 3)
        #expect(transcript.entries.last?.content == .userMessage("Prompt 4 界\n…"))
    }

    @Test func unreadableAndMissingDatabasesFailInsteadOfShowingAnEmptyPreview() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("invalid.db")
        try Data("not sqlite".utf8).write(to: file)
        #expect(throws: AntigravityDatabaseError.self) { try AntigravityTranscriptReader().read(file) }
        #expect(throws: AntigravityDatabaseError.self) { try AntigravityTranscriptReader().read(root.appendingPathComponent("missing.db")) }
    }
}
