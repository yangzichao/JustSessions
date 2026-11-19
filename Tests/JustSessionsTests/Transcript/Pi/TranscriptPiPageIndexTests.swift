import Foundation
import Testing

@testable import JustSessions

struct TranscriptPiPageIndexTests {
    @Test(arguments: [1, 7, 64, 333, 4_096, 1 << 20])
    func everyChunkSizeFindsTheBranchALineAtATimeFinds(chunkSize: Int) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var generator = SeededRandomNumberGenerator(seed: UInt64(chunkSize))
        var shownCount = 0
        for trial in 0..<20 {
            let file = directory.appendingPathComponent("session-\(trial).jsonl")
            try Self.randomSession(using: &generator).write(to: file)
            let index = try TranscriptFileIndex.read(file)
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            let expected = try Self.lineAtATime(in: index, handle: handle)
            #expect(
                try TranscriptPiPageIndex.records(in: index, handle: handle, limits: TranscriptPageLimits(), chunkSize: chunkSize)
                    == expected)
            shownCount += expected.count
        }
        #expect(shownCount > 100)
    }

    @Test(arguments: [1, 64, 1 << 20])
    func aLineOverTheRecordLimitFailsTheScan(chunkSize: Int) throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try SampleTranscriptLines.fileContents([
            Self.message("a", parent: nil, text: "Short"),
            Self.message("b", parent: "a", text: String(repeating: "x", count: 600)),
        ]).write(to: fixture.file)
        var limits = TranscriptPageLimits()
        limits.maximumRecordByteCount = 512
        let index = try TranscriptFileIndex.read(fixture.file)
        let handle = try FileHandle(forReadingFrom: fixture.file)
        defer { try? handle.close() }
        #expect(throws: CocoaError(.fileReadTooLarge)) {
            try TranscriptPiPageIndex.records(in: index, handle: handle, limits: limits, chunkSize: chunkSize)
        }
    }

    @Test func aFileCutShortBeforeALineOverTheLimitFailsAsChanged() throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let short = Self.message("a", parent: nil, text: "Short")
        try SampleTranscriptLines.fileContents([short, Self.message("b", parent: "a", text: String(repeating: "x", count: 600))]).write(
            to: fixture.file)
        var limits = TranscriptPageLimits()
        limits.maximumRecordByteCount = 512
        let index = try TranscriptFileIndex.read(fixture.file)
        try Data(short.utf8.prefix(20)).write(to: fixture.file)
        let handle = try FileHandle(forReadingFrom: fixture.file)
        defer { try? handle.close() }
        #expect(throws: TranscriptPagingError.sourceChanged) {
            try TranscriptPiPageIndex.records(in: index, handle: handle, limits: limits)
        }
    }

    @Test func aFileCutShortSinceItsIndexFailsTheScan() throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        let lines = (0..<40).map { Self.message("m\($0)", parent: $0 == 0 ? nil : "m\($0 - 1)", text: "Message \($0)") }
        try SampleTranscriptLines.fileContents(lines).write(to: fixture.file)
        let index = try TranscriptFileIndex.read(fixture.file)
        try SampleTranscriptLines.fileContents(Array(lines.prefix(20))).write(to: fixture.file)
        let handle = try FileHandle(forReadingFrom: fixture.file)
        defer { try? handle.close() }
        #expect(throws: TranscriptPagingError.sourceChanged) {
            try TranscriptPiPageIndex.records(in: index, handle: handle, limits: TranscriptPageLimits())
        }
    }

    private static func randomSession(using generator: inout SeededRandomNumberGenerator) -> Data {
        var lines = [#"{"type":"session","version":3,"id":"s"}"#]
        var ids: [String] = []
        for number in 0..<Int.random(in: 1...60, using: &generator) {
            let id = "e\(number)"
            let parent = ids.isEmpty || Int.random(in: 0..<5, using: &generator) == 0 ? ids.randomElement(using: &generator) : ids.last
            let text = String(repeating: "word ", count: Int.random(in: 0...(Bool.random(using: &generator) ? 20 : 400), using: &generator))
            switch Int.random(in: 0..<6, using: &generator) {
            case 0:
                lines.append(
                    #"{"message":{"role":"user","content":"\#(text)"},"parentId":\#(parent.map { "\"\($0)\"" } ?? "null"),"id":"\#(id)","type":"message"}"#
                )
            case 1:
                lines.append(
                    #"{"type":"model_change","id":"\#(id)","parentId":\#(parent.map { "\"\($0)\"" } ?? "null"),"timestamp":"2026-09-30T10:00:00.000Z","modelId":"m"}"#
                )
            case 2:
                let image = Bool.random(using: &generator) ? #",{"type":"image","data":"AAAA","mimeType":"image/png"}"# : ""
                lines.append(
                    #"{"type":"message","id":"\#(id)","parentId":\#(parent.map { "\"\($0)\"" } ?? "null"),"timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"toolResult","toolCallId":"t","content":[{"type":"text","text":"\#(text)"}\#(image)]}}"#
                )
            default: lines.append(message(id, parent: parent, text: text))
            }
            if Int.random(in: 0..<8, using: &generator) == 0 { lines.append("") }
            ids.append(id)
        }
        let separator = Bool.random(using: &generator) ? "\n" : "\r\n"
        return Data((lines.joined(separator: separator) + (Bool.random(using: &generator) ? separator : "")).utf8)
    }

    private static func message(_ id: String, parent: String?, text: String) -> String {
        #"{"type":"message","id":"\#(id)","parentId":\#(parent.map { "\"\($0)\"" } ?? "null"),"timestamp":"2026-09-30T10:00:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"\#(text)"}]}}"#
    }

    private static func lineAtATime(in index: TranscriptFileIndex, handle: FileHandle) throws -> [Int] {
        let links = try index.lineStarts.indices.compactMap { record -> PiEntryLink? in
            var data = try #require(
                try index.readRecord(at: record, from: handle, maximumByteCount: TranscriptPageLimits().maximumRecordByteCount))
            while data.last == 10 || data.last == 13 { data.removeLast() }
            return PiEntryLink(line: data, lineIndex: record)
        }
        return PiActiveBranch.entries(in: links).filter(\.mightBeShown).map(\.lineIndex)
    }
}
