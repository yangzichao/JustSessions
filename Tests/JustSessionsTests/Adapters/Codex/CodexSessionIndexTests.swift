import Foundation
import Testing
@testable import JustSessions

struct CodexSessionIndexTests {
    @Test func theLastLineForASessionWins() {
        let index = CodexSessionIndex(text: """
        {"id":"a","thread_name":"First name","updated_at":"2026-09-24T10:00:00Z"}
        {"id":"b","thread_name":"Other session"}
        {"id":"a","thread_name":"Renamed","updated_at":"2026-09-24T11:00:00Z"}
        """)

        #expect(index.entry(forSessionID: "a")?.threadName == "Renamed")
        #expect(index.entry(forSessionID: "a")?.updatedAt == ConversationMetadata.date("2026-09-24T11:00:00Z"))
        #expect(index.entry(forSessionID: "b")?.threadName == "Other session")
        #expect(index.entry(forSessionID: "b")?.updatedAt == nil)
    }

    @Test func linesWithoutAnIDOrThreadNameAreSkipped() {
        let index = CodexSessionIndex(text: """
        {"thread_name":"No session"}
        {"id":"c"}
        {"id":"d","thread_name":7}
        not json
        """)

        #expect(index.entry(forSessionID: "c") == nil)
        #expect(index.entry(forSessionID: "d") == nil)
    }

    @Test func aCodexFolderWithoutAnIndexHasNoEntries() throws {
        let codexDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: codexDirectory) }

        #expect(CodexSessionIndex(codexDirectory: codexDirectory).entry(forSessionID: "a") == nil)
    }
}
