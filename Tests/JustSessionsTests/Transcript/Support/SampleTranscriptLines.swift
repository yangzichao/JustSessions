import Foundation
import Testing
@testable import JustSessions

/// Session files as the CLIs write them, one JSON object per line, for tests that damage or interleave them.
enum SampleTranscriptLines {
    static let claude = [
        #"{"type":"user","timestamp":"2026-09-24T10:00:00.000Z","message":{"role":"user","content":"Fix the build"}}"#,
        #"{"type":"assistant","timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Looking at it."},{"type":"tool_use","name":"Bash","input":{"command":"swift build"}}]}}"#,
        #"{"type":"assistant","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/Package.swift"}}]}}"#,
        #"{"type":"user","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#,
        #"{"type":"assistant","timestamp":"2026-09-24T10:00:04.000Z","message":{"role":"assistant","content":"Fixed. Café ☕️ 修好了"}}"#,
        #"{"type":"user","timestamp":"2026-09-24T10:00:05.000Z","message":{"role":"user","content":"Thanks"}}"#,
    ]

    static let codex = [
        #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"session_meta","payload":{"id":"abc","cwd":"/tmp"}}"#,
        #"{"timestamp":"2026-09-24T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Add a test"}]}}"#,
        #"{"timestamp":"2026-09-24T10:00:02.000Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"bash\",\"-lc\",\"swift test\"]}"}}"#,
        #"{"timestamp":"2026-09-24T10:00:03.000Z","type":"response_item","payload":{"type":"function_call_output","output":"ok"}}"#,
        #"{"timestamp":"2026-09-24T10:00:03.500Z","type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","input":"*** Begin Patch"}}"#,
        #"{"timestamp":"2026-09-24T10:00:04.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Done"}}"#,
        #"{"timestamp":"2026-09-24T10:00:05.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Done. 完成 ✅"}]}}"#,
        #"{"timestamp":"2026-09-24T10:00:06.000Z","type":"compacted","payload":{"message":""}}"#,
        #"{"timestamp":"2026-09-24T10:00:07.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Next"}]}}"#,
    ]

    /// Lines neither reader shows anything for: not JSON, not an object, or an object of an unexpected shape.
    static let unusable: [Data] = [
        "not json", "{", "}", "[1,2,3]", "null", "\"just a string\"", "{\"type\":",
        #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"response_item","payload":{"type":"message""#,
        #"{"type":"user","message":"not an object"}"#,
        #"{"type":"assistant","message":{"content":42}}"#,
        #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":"not an array"}}"#,
        #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"response_item","payload":"not an object"}"#,
        "\r",
    ].map { Data($0.utf8) } + [Data([0xFF, 0xFE, 0x00, 0x7B]), Data([0xC3])]

    static func fileContents(_ lines: [Data]) -> Data {
        Data(lines.joined(separator: [0x0A])) + [0x0A]
    }

    static func fileContents(_ lines: [String]) -> Data {
        fileContents(lines.map { Data($0.utf8) })
    }
}

/// Reads a session file the way the preview does, for one tool.
struct TranscriptFileReader: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let sampleLines: [String]
    private let readFile: @Sendable (URL) throws -> TranscriptContent

    static let claude = TranscriptFileReader(testDescription: "Claude Code", sampleLines: SampleTranscriptLines.claude) {
        try ClaudeTranscriptReader().read($0)
    }
    static let codex = TranscriptFileReader(testDescription: "Codex", sampleLines: SampleTranscriptLines.codex) {
        try CodexTranscriptReader().read($0)
    }
    static let all = [claude, codex]

    private init(testDescription: String, sampleLines: [String], readFile: @escaping @Sendable (URL) throws -> TranscriptContent) {
        self.testDescription = testDescription
        self.sampleLines = sampleLines
        self.readFile = readFile
    }

    func read(_ contents: Data, in directory: URL) throws -> TranscriptContent {
        let file = directory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try contents.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try readFile(file)
    }
}
