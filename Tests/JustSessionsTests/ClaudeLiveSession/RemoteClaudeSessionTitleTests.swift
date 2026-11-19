import Foundation
import Testing

@testable import JustSessions

struct RemoteClaudeSessionTitleTests {
    static let sessionID = "3dba4b81-0805-49c2-bbc7-84b61e334cbe"

    @Test func theNameAndActivitySurviveJSONEscapesAndUnicode() throws {
        let name = "部署 \"quoted\" \\ path; #{pane_id}"
        let reason = "Allow \"a:b\"?"
        let title = try Self.title(record: [
            "sessionId": Self.sessionID, "name": name, "nameSource": "user",
            "status": "waiting", "waitingFor": reason,
        ])
        let record = try #require(RemoteClaudeSessionTitle.record(inTerminalTitle: title))
        #expect(record.sessionID == Self.sessionID)
        #expect(record.userChosenName == name)
        #expect(record.activity == .needsInput(reason: reason))
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: title, of: .claude) == record.activity)
        #expect(RemoteCLIActivityTitle.activity(inTerminalTitle: title, of: .pi) == nil)
        #expect(!title.contains("#{pane_id}"))
    }

    @Test func anExplicitTranscriptNameBacksUpAnUnnamedRegistry() throws {
        let title = try Self.title(
            record: ["sessionId": Self.sessionID, "status": "idle"],
            transcript: ["type": "custom-title", "sessionId": Self.sessionID, "customTitle": "New name ✓"]
        )
        #expect(RemoteClaudeSessionTitle.record(inTerminalTitle: title)?.userChosenName == "New name ✓")
    }

    @Test func aCurrentRegistryNameWinsOverACachedTranscriptLine() throws {
        let title = try Self.title(
            record: ["sessionId": Self.sessionID, "name": "Current name", "nameSource": "user", "status": "idle"],
            transcript: ["type": "custom-title", "sessionId": Self.sessionID, "customTitle": "Previous name"]
        )
        #expect(RemoteClaudeSessionTitle.record(inTerminalTitle: title)?.userChosenName == "Current name")
    }

    @Test func anotherSessionsTitleAndIncompleteTranscriptLinesCannotRenameThisSession() throws {
        for transcript in [
            ["type": "custom-title", "sessionId": UUID().uuidString, "customTitle": "Old session"],
            ["type": "assistant", "sessionId": Self.sessionID, "customTitle": "Not a rename"],
            ["type": "custom-title", "customTitle": "No session"],
            ["type": "custom-title", "sessionId": Self.sessionID, "customTitle": "  "],
        ] {
            let title = try Self.title(record: ["sessionId": Self.sessionID, "status": "idle"], transcript: transcript)
            #expect(RemoteClaudeSessionTitle.record(inTerminalTitle: title)?.userChosenName == nil)
        }
    }

    @Test func malformedOrOversizedRecordsAndOrdinaryTitlesTellNothing() throws {
        let validTitle = try Self.title(record: ["sessionId": Self.sessionID, "status": "idle"])
        for title in [
            "", "✳ A topic", "justsessions-activity:idle:", "justsessions-claude:not-base64:",
            "justsessions-claude:e30=:", validTitle + ":extra", String(validTitle.dropLast()),
            try Self.title(record: ["sessionId": "../../escape", "name": "Bad", "nameSource": "user"]),
            try Self.title(record: ["sessionId": Self.sessionID, "name": String(repeating: "x", count: 40000)]),
        ] {
            #expect(RemoteClaudeSessionTitle.record(inTerminalTitle: title) == nil)
        }
    }

    static func title(record: [String: String], transcript: [String: String]? = nil) throws -> String {
        let recordData = try JSONSerialization.data(withJSONObject: record)
        let titleData = try transcript.map { try JSONSerialization.data(withJSONObject: $0) }
        return RemoteClaudeSessionTitle.titlePrefix + recordData.base64EncodedString() + ":"
            + (titleData?.base64EncodedString() ?? "")
    }
}
