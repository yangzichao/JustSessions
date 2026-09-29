import Foundation
import Testing
@testable import JustSessions

struct JSONLinesReaderTests {
    @Test func linesSplitAcrossChunksArriveWhole() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: file) }
        try "first line\n\nsecond, longer line\nlast line without newline".write(to: file, atomically: true, encoding: .utf8)

        var lines: [String] = []
        try JSONLinesReader.forEachLine(in: file, chunkSize: 4) { lines.append(String(decoding: $0, as: UTF8.self)) }

        #expect(lines == ["first line", "second, longer line", "last line without newline"])
    }

    @Test func leadingLinesStopAtTheByteLimit() throws {
        let file = try writeTemporaryFile("first\n\nsecond\nthird\n")
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(strings(JSONLinesReader.leadingLines(in: file, maximumByteCount: 10)) == ["first", "sec"])
        #expect(strings(JSONLinesReader.leadingLines(in: file, maximumByteCount: 100)) == ["first", "second", "third"])
    }

    @Test func trailingLinesLeaveOutTheLineTheByteLimitCutsInto() throws {
        let file = try writeTemporaryFile("first\nsecond\nthird\n")
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(strings(JSONLinesReader.trailingLines(in: file, maximumByteCount: 9)) == ["third"])
        #expect(strings(JSONLinesReader.trailingLines(in: file, maximumByteCount: 100)) == ["first", "second", "third"])
    }

    @Test func aMissingFileHasNoLines() {
        let missingFile = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")

        #expect(JSONLinesReader.leadingLines(in: missingFile, maximumByteCount: 100).isEmpty)
        #expect(JSONLinesReader.trailingLines(in: missingFile, maximumByteCount: 100).isEmpty)
    }

    private func writeTemporaryFile(_ contents: String) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private func strings(_ lines: [Data]) -> [String] {
        lines.map { String(decoding: $0, as: UTF8.self) }
    }
}
