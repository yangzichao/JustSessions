import Foundation
import Testing
@testable import JustSessions

struct ClaudeLiveSessionRegistryTests {
    private static let sessionID = "70b71200-8814-4822-a2e5-24abf31f7cbd"

    @Test func readsTheNameChosenWithRename() throws {
        // Shape copied from a real `~/.claude/sessions/<pid>.json` written by Claude Code 2.1.281 after `/rename`.
        let json = """
        {"pid":14821,"sessionId":"\(Self.sessionID)","cwd":"/Users/example/project","startedAt":1790264417562,\
        "version":"2.1.281","kind":"interactive","entrypoint":"cli","name":"fix-terminal-color-environment",\
        "nameSource":"user","nameSince":1790264423665,"status":"busy","updatedAt":1790264450064}
        """

        let record = try #require(ClaudeLiveSessionRecord(jsonData: Data(json.utf8)))

        #expect(record.sessionID == Self.sessionID)
        #expect(record.userChosenName == "fix-terminal-color-environment")
    }

    @Test func ignoresNamesTheUserDidNotChoose() throws {
        let derived = #"{"sessionId":"\#(Self.sessionID)","name":"justsessions-03","nameSource":"derived"}"#
        let unmarked = #"{"sessionId":"\#(Self.sessionID)","name":"Some desktop title"}"#
        let unnamed = #"{"sessionId":"\#(Self.sessionID)"}"#

        for json in [derived, unmarked, unnamed] {
            let record = try #require(ClaudeLiveSessionRecord(jsonData: Data(json.utf8)))
            #expect(record.userChosenName == nil)
        }
    }

    @Test func cleansTheChosenNameLikeOtherTitles() throws {
        let json = #"{"sessionId":"\#(Self.sessionID)","name":"  Padded name \n second line","nameSource":"user"}"#

        let record = try #require(ClaudeLiveSessionRecord(jsonData: Data(json.utf8)))

        #expect(record.userChosenName == "Padded name")
    }

    @Test func rejectsMalformedRecords() {
        #expect(ClaudeLiveSessionRecord(jsonData: Data("not json".utf8)) == nil)
        #expect(ClaudeLiveSessionRecord(jsonData: Data(#"{"name":"x","nameSource":"user"}"#.utf8)) == nil)
        #expect(ClaudeLiveSessionRecord(jsonData: Data(#"{"sessionId":"../escape","nameSource":"user"}"#.utf8)) == nil)
    }

    @Test func looksUpTheRecordByProcessID() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionsDirectory = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        try #"{"sessionId":"\#(Self.sessionID)","name":"Renamed","nameSource":"user"}"#
            .write(to: sessionsDirectory.appendingPathComponent("4242.json"), atomically: true, encoding: .utf8)
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: root)

        #expect(registry.record(forProcessID: 4242)?.userChosenName == "Renamed")
        #expect(registry.record(forProcessID: 4243) == nil)
        #expect(registry.record(forProcessID: 0) == nil)
        #expect(registry.record(forProcessID: -1) == nil)
    }

    @Test func seesARenameWrittenAfterTheFirstRead() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessionsDirectory = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        let recordFile = sessionsDirectory.appendingPathComponent("4242.json")
        let registry = ClaudeLiveSessionRegistry(configurationDirectory: root)

        try #"{"sessionId":"\#(Self.sessionID)","name":"justsessions-03","nameSource":"derived"}"#
            .write(to: recordFile, atomically: true, encoding: .utf8)
        #expect(registry.record(forProcessID: 4242)?.userChosenName == nil)

        try #"{"sessionId":"\#(Self.sessionID)","name":"Renamed live","nameSource":"user"}"#
            .write(to: recordFile, atomically: true, encoding: .utf8)
        #expect(registry.record(forProcessID: 4242)?.userChosenName == "Renamed live")
    }
}
