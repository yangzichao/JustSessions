import Foundation
import Testing
@testable import JustSessions

struct AppendedJSONLinesReaderTests {
    @Test func returnsOnlyTheLinesAppendedSinceTheLastCall() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data("{\"before\":1}\n".utf8).write(to: file)
        var reader = AppendedJSONLinesReader(file: file)

        let firstLines = reader.newLines()
        try append("{\"after\":1}\n{\"after\":2}\n", to: file)
        let appendedLines = reader.newLines()
        let unchangedLines = reader.newLines()

        #expect(firstLines.isEmpty)
        #expect(appendedLines == jsonLines(["{\"after\":1}", "{\"after\":2}"]))
        #expect(unchangedLines.isEmpty)
    }

    @Test func waitsForALineStillBeingWritten() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data().write(to: file)
        var reader = AppendedJSONLinesReader(file: file)
        _ = reader.newLines()

        try append("{\"whole\":1}\n{\"half", to: file)
        let linesWhileWriting = reader.newLines()
        try append("\":2}\n", to: file)
        let linesOnceWritten = reader.newLines()

        #expect(linesWhileWriting == jsonLines(["{\"whole\":1}"]))
        #expect(linesOnceWritten == jsonLines(["{\"half\":2}"]))
    }

    @Test func startsAgainFromTheEndOfAFileThatShrank() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data("{\"old\":1}\n{\"old\":2}\n".utf8).write(to: file)
        var reader = AppendedJSONLinesReader(file: file)
        _ = reader.newLines()

        try Data("{\"new\":1}\n".utf8).write(to: file)
        let linesAfterReplacing = reader.newLines()
        try append("{\"new\":2}\n", to: file)

        #expect(linesAfterReplacing.isEmpty)
        #expect(reader.newLines() == jsonLines(["{\"new\":2}"]))
    }

    @Test func catchesUpOnOnlyTheLastBytesAfterALongGap() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data().write(to: file)
        var reader = AppendedJSONLinesReader(file: file)
        _ = reader.newLines()
        let filler = String(repeating: "x", count: Int(AppendedJSONLinesReader.maximumCatchUpByteCount))

        try append("{\"filler\":\"\(filler)\"}\n{\"last\":1}\n", to: file)

        #expect(reader.newLines() == jsonLines(["{\"last\":1}"]))
    }

    @Test func readsNothingFromAMissingFile() {
        var reader = AppendedJSONLinesReader(file: URL(fileURLWithPath: "/tmp/justsessions-tests/missing-\(UUID().uuidString).jsonl"))

        #expect(reader.newLines().isEmpty)
    }

    private func append(_ text: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
    }
}
