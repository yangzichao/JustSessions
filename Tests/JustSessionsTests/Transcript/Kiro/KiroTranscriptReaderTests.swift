import Foundation
import Testing
@testable import JustSessions

struct KiroTranscriptReaderTests {
    @Test func showsVisibleConversationAndGroupsToolsWithoutThinkingOrToolOutput() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let transcript = try TranscriptFileReader.kiro.read(SampleTranscriptLines.fileContents(KiroTranscriptSamples.lines), in: directory)

        #expect(transcript.entries.map(\.content) == [
            .userMessage("Fix the build"),
            .assistantMessage("Looking at it."),
            .toolCalls(["shell · swift build", "read · /tmp/Package.swift"]),
            .assistantMessage("Fixed. Café ☕️ 修好了"),
            .userMessage("Thanks"),
        ])
        #expect(transcript.entries.map(\.startsTurn) == [true, true, false, false, true])
        #expect(transcript.entries.first?.timestamp == Date(timeIntervalSince1970: 1_790_244_000))
        #expect(transcript.entries[1].timestamp == nil)
    }

    @Test func promptPartsImagesAndSerializedToolArgumentsUseTheSharedPreviewFormat() throws {
        let records: [[String: Any]] = [
            ["kind": "Prompt", "data": ["content": [
                ["kind": "text", "data": "Look at this"],
                ["kind": "image", "data": "private image bytes"],
                ["kind": "text", "data": "What changed?"],
            ]]],
            ["kind": "AssistantMessage", "data": ["content": [
                ["kind": "toolUse", "data": ["name": "shell", "input": #"{"command":"swift test"}"#]],
                ["kind": "toolUse", "data": ["name": "read", "input": "not JSON"]],
                ["kind": "unknown", "data": "Leave this out"],
                ["kind": "toolUse", "data": "not an object"],
            ]]],
        ]
        let file = try TranscriptTestFiles.write(records)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(try KiroTranscriptReader().read(file).entries.map(\.content) == [
            .userMessage("Look at this\n\n[Image]\n\nWhat changed?"),
            .toolCalls(["shell · swift test", "read"]),
        ])
    }

    @Test(arguments: [1_790_244_000.25, 1_790_244_000_250.0])
    func timestampsInSecondsOrMillisecondsPreserveTheirFraction(_ timestamp: Double) {
        let data: [String: Any] = ["meta": ["timestamp": timestamp]]
        #expect(KiroTranscriptTimestamp.date(in: [:], data: data) == Date(timeIntervalSince1970: 1_790_244_000.25))
    }

    @Test func absentBooleanAndMalformedTimestampsDoNotInventDates() {
        for value: Any in [true, "not a date", NSNull()] {
            #expect(KiroTranscriptTimestamp.date(in: [:], data: ["meta": ["timestamp": value]]) == nil)
        }
        #expect(KiroTranscriptTimestamp.date(in: [:], data: [:]) == nil)
        #expect(KiroTranscriptTimestamp.date(in: ["timestamp": "2026-09-24T10:00:00Z"], data: [:])
            == ISO8601TimestampParser.shared.date(from: "2026-09-24T10:00:00Z"))
    }

    @Test func thePreviewLoaderReadsLocalAndMirroredKiroSessions() async throws {
        let file = try TranscriptTestFiles.write([
            ["kind": "Prompt", "data": ["content": [["kind": "text", "data": "Preview me"]]]],
        ])
        defer { try? FileManager.default.removeItem(at: file) }
        let expected = try KiroTranscriptReader().read(file)
        for host: SessionHost in [.thisMac, .ssh("devbox")] {
            #expect(try await TranscriptLoader.load(.fixture(provider: .kiro, sourceFile: file, host: host)) == .loaded(expected))
        }
    }
}
