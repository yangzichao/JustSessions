import Foundation
import Testing
@testable import JustSessions

/// `mightContainTranscriptItem` skips most of a rollout without parsing it. Skipping must never lose anything:
/// no line it rejects would have added to the transcript.
struct CodexLineFilterPropertyTests {
    private static let recordTypes = ["response_item", "response_item", "event_msg", "compacted", "turn_context", "session_meta"]
    private static let payloadTypes = [
        "message", "function_call", "custom_tool_call", "function_call_output", "custom_tool_call_output", "reasoning", "web_search_call",
    ]
    private static let payloadFields = [
        #""role":"user""#, #""role":"assistant""#, #""role":"developer""#,
        #""content":[{"type":"input_text","text":"Question"}]"#, #""content":[{"type":"output_text","text":"Answer"}]"#,
        #""name":"shell""#, #""arguments":"{\"command\":\"ls\"}""#, #""input":"*** Begin Patch""#, #""output":"ok""#,
        #""content":[{"payload":{"type":"reasoning"}}]"#,
    ]

    @Test func noLineThatAddsToTheTranscriptIsSkipped() throws {
        var generator = SeededRandomNumberGenerator(seed: 0xC0DE)
        var skippedLineCount = 0
        var shownLineCount = 0

        for _ in 0..<3_000 {
            let line = Data(Self.randomLine(using: &generator).utf8)
            let record = try #require(ConversationMetadata.object(from: line), "\(String(decoding: line, as: UTF8.self))")
            var builder = TranscriptBuilder()
            CodexTranscriptReader().append(record, to: &builder)
            let addsToTranscript = !builder.build().entries.isEmpty

            if !CodexTranscriptReader.mightContainTranscriptItem(line) {
                skippedLineCount += 1
                #expect(!addsToTranscript, "\(String(decoding: line, as: UTF8.self))")
            }
            if addsToTranscript { shownLineCount += 1 }
        }

        // Both kinds of line came up, so the check above was not vacuous.
        #expect(skippedLineCount > 100)
        #expect(shownLineCount > 100)
    }

    @Test(arguments: [
        #"{"timestamp":"t", "type": "response_item", "payload": {"type":"function_call"}}"#,
        #"{"timestamp":"t","type":"response_item","payload":{"name":"shell","content":[{"payload":{"type":"reasoning"}}],"type":"function_call"}}"#,
        #"{"timestamp":"t","type":"response\u005fitem","payload":{"type":"message"}}"#,
        #"{"timestamp":"t","meta":{"type":"event_msg"},"type":"compacted"}"#,
    ])
    func linesInAnotherLayoutAreParsed(_ line: String) {
        #expect(CodexTranscriptReader.mightContainTranscriptItem(Data(line.utf8)))
    }

    @Test(arguments: [
        #"{"timestamp":"t","ordinal":1,"type":"event_msg","payload":{"type":"agent_message","message":"Done"}}"#,
        #"{"timestamp":"t","ordinal":2,"type":"response_item","payload":{"type":"reasoning","summary":[]}}"#,
        #"{"timestamp":"t","type":"turn_context","payload":{"cwd":"/tmp"}}"#,
    ])
    func linesCodexWritesThatShowNothingAreSkipped(_ line: String) {
        #expect(!CodexTranscriptReader.mightContainTranscriptItem(Data(line.utf8)))
    }

    /// A payload with its fields in random order, in Codex's layouts or in others a line could have: keys in
    /// another order, spaces, something nested before the record's type, or an escaped type.
    private static func randomLine(using generator: inout SeededRandomNumberGenerator) -> String {
        let payloadType = payloadTypes.randomElement(using: &generator)!
        var fields = payloadFields.shuffled(using: &generator).prefix(Int.random(in: 0...4, using: &generator)).map { $0 }
        let typeField = "\"type\":\"\(payloadType)\""
        fields.insert(typeField, at: Bool.random(using: &generator) ? 0 : Int.random(in: 0...fields.count, using: &generator))
        let payload = "{" + fields.joined(separator: ",") + "}"
        let recordType = recordTypes.randomElement(using: &generator)!
        let timestamp = "\"timestamp\":\"2026-09-24T10:00:00.000Z\""

        return switch Int.random(in: 0..<6, using: &generator) {
        case 0: "{\(timestamp),\"type\":\"\(recordType)\",\"payload\":\(payload)}"
        case 1: "{\(timestamp),\"ordinal\":7,\"type\":\"\(recordType)\",\"payload\":\(payload)}"
        case 2: "{\"payload\":\(payload),\(timestamp),\"type\":\"\(recordType)\"}"
        case 3: "{\(timestamp), \"type\": \"\(recordType)\", \"payload\": \(payload)}"
        case 4: "{\(timestamp),\"meta\":{\"type\":\"event_msg\"},\"type\":\"\(recordType)\",\"payload\":\(payload)}"
        default: "{\(timestamp),\"type\":\"\(recordType.replacingOccurrences(of: "_", with: "\\u005f"))\",\"payload\":\(payload)}"
        }
    }
}
