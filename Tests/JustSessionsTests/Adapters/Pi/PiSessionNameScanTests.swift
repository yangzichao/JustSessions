import Foundation
import Testing

@testable import JustSessions

struct PiSessionNameScanTests {
    private func writeLines(_ lines: [String], to file: URL) throws {
        try lines.map { $0 + "\n" }.joined().write(to: file, atomically: true, encoding: .utf8)
    }

    private func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }

    private var manyPrompts: [String] {
        (0..<2_000).map { PiSessionFolderFixture.userMessage("Prompt \($0) " + String(repeating: "x", count: 150)) }
    }

    @Test func findsANameMegabytesBeforeTheEnd() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try writeLines([PiSessionFolderFixture.sessionName("Login fix")] + manyPrompts, to: file)

        let scan = try #require(PiSessionNameScan.scan(file, continuing: nil))

        #expect(try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int ?? 0 > 262_144)
        #expect(scan.latestName == "Login fix")
        #expect(scan.scannedByteCount == (try Data(contentsOf: file)).count)
    }

    @Test func readsOnFromWhereThePreviousScanStopped() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try writeLines([PiSessionFolderFixture.sessionName("Written before"), PiSessionFolderFixture.userMessage("Hi")], to: file)
        let firstScan = try #require(PiSessionNameScan.scan(file, continuing: nil))
        let kept = PiSessionNameScan(latestName: "Kept", scannedByteCount: firstScan.scannedByteCount, endingBytes: firstScan.endingBytes)

        #expect(PiSessionNameScan.scan(file, continuing: kept)?.latestName == "Kept")

        try append(PiSessionFolderFixture.userMessage("More") + "\n" + PiSessionFolderFixture.sessionName("Added later") + "\n", to: file)

        #expect(PiSessionNameScan.scan(file, continuing: kept)?.latestName == "Added later")
    }

    @Test func startsOverWhenTheFileNoLongerHoldsWhatThePreviousScanRead() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try writeLines([PiSessionFolderFixture.sessionName("Old file"), PiSessionFolderFixture.userMessage("Hi")], to: file)
        let previous = try #require(PiSessionNameScan.scan(file, continuing: nil))

        try writeLines(
            [PiSessionFolderFixture.userMessage("Replaced"), PiSessionFolderFixture.userMessage("and longer than before")], to: file)
        #expect(PiSessionNameScan.scan(file, continuing: previous)?.latestName == nil)

        try writeLines([PiSessionFolderFixture.sessionName("New")], to: file)
        #expect(PiSessionNameScan.scan(file, continuing: previous)?.latestName == "New")
    }

    @Test func leavesAnUnfinishedLastLineForTheNextScan() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let nameLine = PiSessionFolderFixture.sessionName("Being written")
        let cut = nameLine.index(nameLine.startIndex, offsetBy: 40)
        try writeLines([PiSessionFolderFixture.userMessage("Hi")], to: file)
        try append(String(nameLine[..<cut]), to: file)

        let partial = try #require(PiSessionNameScan.scan(file, continuing: nil))
        #expect(partial.latestName == nil)
        #expect(partial.scannedByteCount == Data((PiSessionFolderFixture.userMessage("Hi") + "\n").utf8).count)

        try append(String(nameLine[cut...]) + "\n", to: file)
        #expect(PiSessionNameScan.scan(file, continuing: partial)?.latestName == "Being written")
    }

    @Test(arguments: [64, 1_000])
    func findsNamesAcrossChunksAndPastLinesTooLongToBeOne(chunkSize: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let longOutput = PiSessionFolderFixture.userMessage(String(repeating: "y", count: PiSessionNameScan.maximumNameLineByteCount * 2))
        try writeLines(
            [
                PiSessionFolderFixture.sessionName("First"),
                longOutput,
                PiSessionFolderFixture.sessionName("After the long line"),
                longOutput,
                PiSessionFolderFixture.userMessage("Last"),
            ], to: file)

        let scan = PiSessionNameScan.scan(file, continuing: nil, chunkSize: chunkSize)

        #expect(scan?.latestName == "After the long line")
        #expect(scan?.scannedByteCount == (try Data(contentsOf: file)).count)
    }

    @Test func takesOnlySessionInfoRecordsAsNames() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try writeLines(
            [
                PiSessionFolderFixture.sessionName("Real name"),
                #"{"type":"custom","data":{"kind":"session_info","name":"Not a name"}}"#,
                PiSessionFolderFixture.userMessage(#"Print \"type\":\"session_info\" lines"#),
                PiSessionFolderFixture.sessionName("   "),
            ], to: file)

        #expect(PiSessionNameScan.scan(file, continuing: nil)?.latestName == "Real name")
    }
}
