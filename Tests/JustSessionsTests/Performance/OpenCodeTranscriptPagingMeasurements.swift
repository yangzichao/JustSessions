import Foundation
import Testing
@testable import JustSessions

/// Measures paging through a long OpenCode session in its database, as the reader and message search do: the latest
/// page, five pages back from it, a page in the middle, and the whole session read for search. Each reader keeps one
/// page source, as the reader does. Reports `Perf | <scenario> | <metric> | <value>` lines, medians of five.
///
/// Messages carry what OpenCode stores: an assistant reply's model, token counts, cost, and paths, and on every fifth
/// prompt a summary with file diffs, which hold whole files.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter OpenCodeTranscriptPagingMeasurements
@Suite(.serialized)
struct OpenCodeTranscriptPagingMeasurements {
    static let sessionID = "ses_long"

    @Test(arguments: [1_000, 10_000])
    func pagingALongSession(messageCount: Int) async throws {
        guard SidebarInteractionMeasurements.isEnabled else { return }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try OpenCodeDatabaseFixture(file: directory.appendingPathComponent("opencode.db"))
        try Self.addSession(to: database, messageCount: messageCount)
        let scenario = "OpenCode session of \(messageCount.formatted()) messages"
        let middleEntryID = TranscriptPageIdentity.entryID(record: messageCount / 2, part: 0)

        perfReport(scenario, "latest page", try await Self.median {
            _ = try await Self.source(database).read(.latest)
        })
        perfReport(scenario, "latest page, then 5 earlier ones", try await Self.median {
            let source = Self.source(database)
            var page = try await source.read(.latest)
            for _ in 0..<5 { page = try await source.read(.before(page.records.lowerBound)) }
        })
        perfReport(scenario, "a page in the middle", try await Self.median {
            _ = try await Self.source(database).read(.around(middleEntryID))
        })
        let conversation = Conversation.fixture(provider: .opencode, sessionID: Self.sessionID, sourceFile: database.file)
        perfReport(scenario, "whole session read for message search", try await Self.median {
            _ = try await SessionMessageTextReader.read(conversation)
        })
        #expect(messageCount > 0) // Record-only: the numbers above are the result.
    }

    private static func source(_ database: OpenCodeDatabaseFixture) -> TranscriptPageSource {
        TranscriptPageSource(file: database.file, provider: .opencode, sessionID: sessionID)
    }

    private static func median(_ work: () async throws -> Void) async throws -> Duration {
        var times: [Duration] = []
        for _ in 0..<5 {
            let start = ContinuousClock.now
            try await work()
            times.append(ContinuousClock.now - start)
        }
        return times.sorted()[2]
    }

    private static func addSession(to database: OpenCodeDatabaseFixture, messageCount: Int) throws {
        try database.addSession(sessionID)
        let diff = #"{"file":"Sources/App/Settings.swift","before":"\#(String(repeating: "let value = 1\\n", count: 300))","after":"\#(String(repeating: "let value = 2\\n", count: 300))","additions":300,"deletions":300}"#
        var messages: [(id: String, session: String, createdAt: Int64, data: String)] = []
        var parts: [(id: String, message: String, session: String, data: String)] = []
        for index in 0..<messageCount {
            let id = String(format: "msg_%06d", index)
            let createdAt = Int64(1_790_000_000_000 + index * 1_000)
            if index % 2 == 0 {
                let summary = index % 10 == 0 ? #"{"title":"Edit settings","diffs":[\#(diff),\#(diff)]}"# : #"{"diffs":[]}"#
                messages.append((id, sessionID, createdAt, #"{"role":"user","time":{"created":\#(createdAt)},"summary":\#(summary),"agent":"build","model":{"providerID":"anthropic","modelID":"claude-sonnet-4-5"}}"#))
                parts.append(("prt_\(id)_text", id, sessionID, #"{"type":"text","text":"Prompt \#(index): tighten the settings layout and keep the sidebar width when the window narrows."}"#))
            } else {
                messages.append((id, sessionID, createdAt, #"{"role":"assistant","time":{"created":\#(createdAt),"completed":\#(createdAt + 900)},"parentID":"msg_\#(index - 1)","modelID":"claude-sonnet-4-5","providerID":"anthropic","mode":"build","agent":"build","path":{"cwd":"/Users/me/app","root":"/Users/me/app"},"cost":0.0123,"tokens":{"input":1200,"output":340,"reasoning":0,"cache":{"read":45000,"write":1200}},"finish":"stop"}"#))
                parts.append(("prt_\(id)_tool", id, sessionID, #"{"type":"tool","tool":"edit","callID":"call_\#(index)","state":{"status":"completed","input":{"filePath":"Sources/App/Settings.swift"},"output":"\#(String(repeating: "updated ", count: 200))","metadata":{"diff":"\#(String(repeating: "+ line\\n", count: 100))"}}}"#))
                parts.append(("prt_\(id)_text", id, sessionID, #"{"type":"text","text":"Reply \#(index): the layout now keeps the sidebar width, and the settings fit at 800 points."}"#))
            }
        }
        try database.addRows(messages: messages, parts: parts)
    }
}
