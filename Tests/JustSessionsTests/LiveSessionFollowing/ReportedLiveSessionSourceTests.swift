import Foundation
import Testing
@testable import JustSessions

/// The Pi and OpenCode sources read what their extension reported; see `LiveSessionReporting`.
struct ReportedLiveSessionSourceTests {
    @Test func aPiSessionIsSavedOnceItsFileExists() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reporting = LiveSessionReporting(directory: directory)
        let sessionID = "01a10925-e202-7606-8b40-1c596fc844c9"
        let sessionFile = directory.appendingPathComponent("sessions/2026-10-04T23-00-40-123Z_\(sessionID).jsonl")
        try writeReport(#"{"pid":4242,"sessionId":"\#(sessionID)","sessionFile":"\#(sessionFile.path)"}"#, for: 4242, in: reporting)
        let source = PiLiveSessionSource(reporting: reporting)

        let session = try #require(source.currentSession(ofCLIProcessID: 4242))
        #expect(session == LiveCLISession(sessionID: sessionID, file: sessionFile))
        #expect(!source.isSaved(session))

        try FileManager.default.createDirectory(at: sessionFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}\n".write(to: sessionFile, atomically: true, encoding: .utf8)
        #expect(source.isSaved(session))
    }

    @Test func anOpenCodeSessionIsSavedOnceTheDatabaseHasItAtTheTopLevel() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reporting = LiveSessionReporting(directory: directory)
        let database = try OpenCodeDatabaseFixture(file: directory.appendingPathComponent("opencode.db"))
        let source = OpenCodeLiveSessionSource(reporting: reporting, databaseFile: database.file)
        try writeReport(#"{"pid":4242,"sessionId":"ses_ef6d4c16effetRHDnvDz5ZoIIN"}"#, for: 4242, in: reporting)
        try writeReport(#"{"pid":4343,"sessionId":null}"#, for: 4343, in: reporting)

        let session = try #require(source.currentSession(ofCLIProcessID: 4242))
        #expect(session == LiveCLISession(sessionID: "ses_ef6d4c16effetRHDnvDz5ZoIIN", file: nil))
        #expect(source.currentSession(ofCLIProcessID: 4343) == nil)
        #expect(!source.isSaved(session))

        try database.addSession("ses_ef6d4c16effetRHDnvDz5ZoIIN")
        try database.addSession("ses_ef6d49184ffeZlaUg1LhI3eZES", parentID: "ses_ef6d4c16effetRHDnvDz5ZoIIN")
        #expect(source.isSaved(session))
        #expect(!source.isSaved(LiveCLISession(sessionID: "ses_ef6d49184ffeZlaUg1LhI3eZES", file: nil)))
    }

    private func writeReport(_ json: String, for processID: Int32, in reporting: LiveSessionReporting) throws {
        try FileManager.default.createDirectory(at: reporting.reportsDirectory, withIntermediateDirectories: true)
        try json.write(to: reporting.reportsDirectory.appendingPathComponent("\(processID).json"), atomically: true, encoding: .utf8)
    }
}
