import Foundation
import Testing
@testable import JustSessions

struct KiroSessionMetadataTests {
    @Test(arguments: [false, true])
    func metadataSplitAroundSessionStateIsReadCompletely(large: Bool) throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("session.json")
        let padding = String(repeating: "x", count: large ? Self.largePadding : 10)
        try #"{"session_id":"a","session_state":{"padding":"\#(padding)"},"cwd":"/project","parent_session_id":"parent","title":"Title"}"#
            .write(to: file, atomically: true, encoding: .utf8)
        let metadata = try #require(KiroSessionMetadata(file: file))
        #expect(metadata.projectPath == "/project")
        #expect(metadata.parentSessionID == "parent")
        #expect(metadata.title == "Title")

        try #"{"session_id":"a","cwd":"/project","session_state":{"padding":"\#(padding)"},"parent_session_id":"parent"}"#
            .write(to: file, atomically: true, encoding: .utf8)
        #expect(KiroSessionMetadata(file: file)?.parentSessionID == "parent")
    }

    private static let largePadding = KiroSessionMetadata.maximumHeadByteCount * 2

    @Test func membersBeforeSessionStateAreReadOnTheirOwn() throws {
        let head = Data(#"{"session_id":"a","cwd":"/x","title":"has \"session_state\" in it", "session_state" : {"unfinished": ["#.utf8)
        let object = try #require(KiroSessionMetadata.objectBeforeSessionState(in: head))
        #expect(object["session_id"] as? String == "a")
        #expect(object["title"] as? String == #"has "session_state" in it"#)
        #expect(object["session_state"] == nil)
    }

    @Test func sessionStateInsideAnotherValueIsNotTheCutPoint() {
        let head = Data(#"{"nested":{"session_state":1},"session_id":"a""#.utf8)
        #expect(KiroSessionMetadata.objectBeforeSessionState(in: head) == nil)
    }

    @Test func largeFilesAreReadFromTheirStartAndSmallOnesWhole() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionID = UUID().uuidString
        let padding = String(repeating: "x", count: KiroSessionMetadata.maximumHeadByteCount * 2)
        let large = root.appendingPathComponent("large.json")
        try #"{"session_id":"\#(sessionID)","cwd":"/Users/me/app","session_state":{"padding":"\#(padding)"}}"#
            .write(to: large, atomically: true, encoding: .utf8)
        let fieldsLast = root.appendingPathComponent("fields-last.json")
        try #"{"session_state":{"padding":"\#(padding)"},"session_id":"\#(sessionID)","cwd":"/Users/me/api"}"#
            .write(to: fieldsLast, atomically: true, encoding: .utf8)
        let small = root.appendingPathComponent("small.json")
        try #"{"cwd":"/Users/me/web","session_id":"\#(sessionID)","session_created_reason":"subagent"}"#
            .write(to: small, atomically: true, encoding: .utf8)

        #expect(KiroSessionMetadata(file: large)?.projectPath == "/Users/me/app")
        #expect(KiroSessionMetadata(file: fieldsLast)?.projectPath == "/Users/me/api")
        #expect(KiroSessionMetadata(file: small)?.createdReason == "subagent")
        #expect(KiroSessionMetadata(file: root.appendingPathComponent("missing.json")) == nil)
    }

    /// Kiro CLI writes the parent before `session_state`, as its own session record orders its fields.
    @Test func theParentSessionIsReadAndAnEmptyOneIsNone() throws {
        let child = Data(#"{"session_id":"a","cwd":"/x","parent_session_id":"p","session_created_reason":"subagent","session_state":{}}"#.utf8)
        let main = Data(#"{"session_id":"b","cwd":"/x","parent_session_id":"","session_created_reason":"subagent","session_state":{}}"#.utf8)

        #expect(KiroSessionMetadata(object: try #require(KiroSessionMetadata.objectBeforeSessionState(in: child)))?.parentSessionID == "p")
        #expect(KiroSessionMetadata(object: try #require(KiroSessionMetadata.objectBeforeSessionState(in: main)))?.parentSessionID == nil)
    }
}
