import Foundation
import Testing

@testable import JustSessions

struct CodexRolloutModelTests {
    private static func turnContext(model: String?, effort: String? = "medium", padding: Int = 0) -> String {
        let model = model.map { #""model":"\#($0)","# } ?? ""
        let effort = effort.map { #""effort":"\#($0)","# } ?? ""
        return
            #"{"timestamp":"2026-10-13T10:00:00Z","type":"turn_context","payload":{\#(model)\#(effort)"cwd":"/Users/me/app","developer_instructions":"\#(String(repeating: "x", count: padding))"}}"#
    }

    private static func output(_ byteCount: Int) -> String {
        #"{"type":"event_msg","payload":{"type":"exec_command_output","output":"\#(String(repeating: "y", count: byteCount))"}}"#
    }

    private func write(_ lines: [String]) throws -> (URL, () -> Void) {
        let directory = try makeTemporaryDirectory()
        let file = directory.appendingPathComponent("rollout.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return (file, { try? FileManager.default.removeItem(at: directory) })
    }

    @Test func theLastTurnContextNamesTheModel() throws {
        let (file, remove) = try write([
            #"{"type":"session_meta","payload":{"id":"s1","cwd":"/Users/me/app"}}"#,
            Self.turnContext(model: "gpt-5.5", effort: "low"),
            Self.output(100),
            Self.turnContext(model: "gpt-6-astra", effort: "ultra"),
            Self.output(100),
        ])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file) == SessionModel(id: "gpt-6-astra", effort: "ultra"))
    }

    /// A long turn writes megabytes after its `turn_context`, past any fixed tail.
    @Test func aTurnContextMegabytesBeforeTheEndIsFound() throws {
        let (file, remove) = try write([
            Self.turnContext(model: "gpt-5.5"),
            Self.output(3 * CodexRolloutModel.chunkByteCount + 12_345),
        ])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file)?.id == "gpt-5.5")
    }

    @Test func aTurnContextCutByAChunkBoundaryIsFound() throws {
        // The marker straddles the boundary one chunk from the end, whatever the line before it holds.
        for shift in [-30, -15, -5, 0, 5] {
            let marker = #""type":"turn_context""#
            let line = Self.turnContext(model: "gpt-5.5")
            let markerOffset = line.range(of: marker)!.lowerBound.utf16Offset(in: line)
            let trailing = Self.output(CodexRolloutModel.chunkByteCount - 200)
            let trailingByteCount = trailing.utf8.count + 1
            let lineEndToMarker = line.utf8.count + 1 - markerOffset
            // Puts the marker `shift` bytes from the chunk boundary counted from the end.
            let padding = max(0, CodexRolloutModel.chunkByteCount - trailingByteCount - lineEndToMarker + shift)
            let (file, remove) = try write([Self.output(1_000), Self.turnContext(model: "gpt-5.5", padding: padding), trailing])
            defer { remove() }

            #expect(CodexRolloutModel.latest(in: file)?.id == "gpt-5.5", "shift \(shift)")
        }
    }

    @Test func aTurnContextLineLongerThanAChunkIsReadWhole() throws {
        let (file, remove) = try write([
            Self.turnContext(model: "gpt-5.5", padding: 2 * CodexRolloutModel.chunkByteCount + 77),
            Self.output(100),
        ])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file) == SessionModel(id: "gpt-5.5", effort: "medium"))
    }

    @Test func aTurnContextWithoutAModelGivesWayToAnEarlierOne() throws {
        let (file, remove) = try write([
            Self.turnContext(model: "gpt-5.5", effort: nil),
            Self.turnContext(model: nil),
            Self.output(100),
        ])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file) == SessionModel(id: "gpt-5.5"))
    }

    /// Text that only mentions a turn context, such as a command's output, holds it inside a JSON string, where its
    /// quotes are escaped, so it never matches.
    @Test func noTurnContextIsNoModel() throws {
        let (file, remove) = try write([
            #"{"type":"session_meta","payload":{"id":"s1","cwd":"/Users/me/app"}}"#,
            #"{"type":"event_msg","payload":{"output":"{\"type\":\"turn_context\",\"payload\":{\"model\":\"fake\"}}"}}"#,
        ])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file) == nil)
    }

    @Test func anEmptyOrMissingFileIsNoModel() throws {
        let (file, remove) = try write([])
        defer { remove() }

        #expect(CodexRolloutModel.latest(in: file) == nil)
        #expect(CodexRolloutModel.latest(in: file.appendingPathExtension("missing")) == nil)
    }
}
