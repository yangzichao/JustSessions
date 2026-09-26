import Foundation
import Testing
@testable import JustSessions

/// Session files are written by other programs, often while the preview reads them. Damaged or unexpected
/// lines are skipped; they never hide the lines around them or stop the file from being read.
struct MalformedTranscriptTests {
    @Test(arguments: TranscriptFileReader.all)
    func samplesShowTheirConversation(_ reader: TranscriptFileReader) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let transcript = try reader.read(SampleTranscriptLines.fileContents(reader.sampleLines), in: directory)

        #expect(transcript.entries.count >= 4)
    }

    @Test(arguments: TranscriptFileReader.all)
    func unusableLinesAnywhereLeaveTheConversationUnchanged(_ reader: TranscriptFileReader) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cleanTranscript = try reader.read(SampleTranscriptLines.fileContents(reader.sampleLines), in: directory)

        for seed in UInt64(1)...20 {
            var generator = SeededRandomNumberGenerator(seed: seed)
            var lines = reader.sampleLines.map { Data($0.utf8) }
            for _ in 0..<Int.random(in: 1...12, using: &generator) {
                lines.insert(SampleTranscriptLines.unusable.randomElement(using: &generator)!, at: Int.random(in: 0...lines.count, using: &generator))
            }

            let transcript = try reader.read(SampleTranscriptLines.fileContents(lines), in: directory)

            #expect(transcript == cleanTranscript, "seed \(seed)")
        }
    }

    @Test(arguments: TranscriptFileReader.all)
    func aLineLongerThanAReadChunkIsSkippedWhole(_ reader: TranscriptFileReader) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cleanTranscript = try reader.read(SampleTranscriptLines.fileContents(reader.sampleLines), in: directory)
        let hugeUnusableLine = Data(("{\"type\":\"" + String(repeating: "x", count: 3 << 20)).utf8)
        var lines = reader.sampleLines.map { Data($0.utf8) }
        lines.insert(hugeUnusableLine, at: 2)

        #expect(try reader.read(SampleTranscriptLines.fileContents(lines), in: directory) == cleanTranscript)
    }

    /// A file cut off at any byte, as when the CLI is still writing it, shows the start of the full conversation.
    /// Only the last entry may differ: a run of tool calls that the rest of the file adds to.
    @Test(arguments: TranscriptFileReader.all)
    func aFileCutOffAnywhereShowsTheStartOfTheConversation(_ reader: TranscriptFileReader) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let contents = SampleTranscriptLines.fileContents(reader.sampleLines)
        let fullEntries = try reader.read(contents, in: directory).entries

        for cutOffset in 0...contents.count {
            let partialEntries = try reader.read(contents.prefix(cutOffset), in: directory).entries
            try #require(partialEntries.count <= fullEntries.count, "cut at \(cutOffset)")
            for (index, entry) in partialEntries.enumerated() {
                let fullEntry = fullEntries[index]
                if index == partialEntries.count - 1,
                   case .toolCalls(let partialSummaries) = entry.content,
                   case .toolCalls(let fullSummaries) = fullEntry.content {
                    #expect(Array(fullSummaries.prefix(partialSummaries.count)) == partialSummaries, "cut at \(cutOffset)")
                    #expect(entry.startsTurn == fullEntry.startsTurn, "cut at \(cutOffset)")
                } else {
                    #expect(entry == fullEntry, "cut at \(cutOffset)")
                }
            }
        }
    }

    @Test(arguments: TranscriptFileReader.all)
    func randomBytesAreReadWithoutFailing(_ reader: TranscriptFileReader) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var generator = SeededRandomNumberGenerator(seed: 0xF0221)
        let alphabet = Array("{}[]\":,\\ a0tuyp".utf8) + [0x0A, 0x0A, 0xFF, 0xC3, 0x00]

        for _ in 0..<200 {
            let contents = Data((0..<Int.random(in: 0...2_000, using: &generator)).map { _ in alphabet.randomElement(using: &generator)! })
            let transcript = try reader.read(contents, in: directory)
            #expect(transcript.entries.map(\.id) == Array(transcript.entries.indices))
        }
    }

    @Test func aToolCallWhoseArgumentsAreNotJSONStillNamesTheTool() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let line = #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{not json"}}"#

        let transcript = try TranscriptFileReader.codex.read(SampleTranscriptLines.fileContents([line]), in: directory)

        #expect(transcript.entries.map(\.content) == [.toolCalls(["shell"])])
    }
}
