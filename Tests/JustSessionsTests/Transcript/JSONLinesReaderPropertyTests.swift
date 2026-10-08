import Foundation
import Testing
@testable import JustSessions

struct JSONLinesReaderPropertyTests {
    /// Random bytes, newlines included, read in chunks of every size give the same lines as splitting the bytes
    /// at each newline. Lines are compared as bytes: a line may end in `\r` or hold invalid UTF-8.
    @Test(arguments: [1, 2, 3, 7, 64, 1 << 20])
    func everyLineArrivesWholeWhateverTheChunkSize(chunkSize: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var generator = SeededRandomNumberGenerator(seed: UInt64(chunkSize))
        let alphabet = Array("ab{}\":, é".utf8) + [0x0A, 0x0A, 0x0A, 0x0D, 0xFF]

        for fileIndex in 0..<50 {
            let contents = Data((0..<Int.random(in: 0...300, using: &generator)).map { _ in alphabet.randomElement(using: &generator)! })
            let file = directory.appendingPathComponent("\(fileIndex).jsonl")
            try contents.write(to: file)

            var lines: [Data] = []
            try JSONLinesReader.forEachLine(in: file, chunkSize: chunkSize) { lines.append(Data($0)) }

            #expect(lines == contents.split(separator: 0x0A).map { Data($0) }, "file \(fileIndex)")
        }
    }

    /// Reading the leading lines in chunks of any size gives the same lines as reading the leading bytes at once, and
    /// stops at the first line its body declines.
    @Test(arguments: [1, 2, 3, 7, 64, 1 << 16])
    func leadingLinesArriveWholeAndStopWhenAsked(chunkSize: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var generator = SeededRandomNumberGenerator(seed: UInt64(chunkSize) + 1)
        let alphabet = Array("ab{}\":, \u{00E9}".utf8) + [0x0A, 0x0A, 0x0A, 0x0D, 0xFF]

        for fileIndex in 0..<50 {
            let contents = Data((0..<Int.random(in: 0...300, using: &generator)).map { _ in alphabet.randomElement(using: &generator)! })
            let file = directory.appendingPathComponent("\(fileIndex).jsonl")
            try contents.write(to: file)
            let limit = Int.random(in: 0...320, using: &generator)
            let expected = JSONLinesReader.leadingLines(in: file, maximumByteCount: limit)

            var lines: [Data] = []
            JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: limit, chunkSize: chunkSize) { lines.append($0); return true }
            var firstTwo: [Data] = []
            JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: limit, chunkSize: chunkSize) {
                firstTwo.append($0)
                return firstTwo.count < 2
            }

            #expect(lines == expected, "file \(fileIndex), limit \(limit)")
            #expect(firstTwo == Array(expected.prefix(2)), "file \(fileIndex), limit \(limit)")
        }
    }

    @Test func stopsReadingOnceItsTaskIsCancelled() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("long.jsonl")
        try String(repeating: "{\"line\":true}\n", count: 1_000).write(to: file, atomically: true, encoding: .utf8)

        let reading = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            var lineCount = 0
            try JSONLinesReader.forEachLine(in: file, chunkSize: 64) { _ in lineCount += 1 }
            return lineCount
        }

        await #expect(throws: CancellationError.self) { try await reading.value }
    }
}
