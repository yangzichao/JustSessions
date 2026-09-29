import Foundation

/// Lines of a Codex session ("rollout") file, in the shape Codex 0.158 writes them, trimmed to a few fields.
enum CodexRolloutLines {
    static let sessionMeta = #"{"timestamp":"2026-09-23T16:03:38.000Z","type":"session_meta","payload":{"id":"01a0cf02-2025-7990-8bb2-80feff2349d4","cwd":"/tmp/project"}}"#
    static let agentMessage = #"{"timestamp":"2026-09-23T16:04:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Working on it"}}"#
    /// A command's output that mentions a turn event. Inside a JSON string its quotes are escaped.
    static let outputMentioningATurnEvent = #"{"timestamp":"2026-09-23T16:04:10.000Z","type":"response_item","payload":{"type":"function_call_output","output":"{\"type\":\"task_complete\"}"}}"#
    /// Not an `event_msg`, though its payload's type reads like a turn event.
    static let otherLineWithATurnEventType = #"{"timestamp":"2026-09-23T16:04:20.000Z","type":"turn_context","payload":{"type":"task_complete"}}"#

    static func turnStarted(at date: Date) -> String {
        #"{"timestamp":"\#(timestamp(date))","type":"event_msg","payload":{"type":"task_started","turn_id":"01a0cf02-21d6-73e2-a606-02299204cdd1","model_context_window":258400}}"#
    }

    static func turnCompleted(at date: Date = .now) -> String {
        #"{"timestamp":"\#(timestamp(date))","type":"event_msg","payload":{"type":"task_complete","turn_id":"01a0cf02-21d6-73e2-a606-02299204cdd1","last_agent_message":"Done."}}"#
    }

    static func turnAborted(at date: Date = .now) -> String {
        #"{"timestamp":"\#(timestamp(date))","type":"event_msg","payload":{"type":"turn_aborted","reason":"interrupted"}}"#
    }

    /// Each line followed by a newline, as Codex writes them.
    static func text(_ lines: [String]) -> Data {
        Data(lines.map { $0 + "\n" }.joined().utf8)
    }

    static func write(_ lines: [String], to file: URL) throws {
        try text(lines).write(to: file)
    }

    static func append(_ text: Data, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: text)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
