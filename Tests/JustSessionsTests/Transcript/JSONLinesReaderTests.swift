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
}
