import Foundation

/// Whether Codex is in the middle of a turn, as its session ("rollout") file records it. A turn starts with a line
/// such as `{"timestamp":"…","type":"event_msg","payload":{"type":"task_started",…}}` and ends with
/// `task_complete`, or with `turn_aborted` when you interrupt it.
enum CodexTurnState: Equatable, Sendable {
    /// A turn started, at the time its line was written when known, and has not ended.
    case inTurn(startedAt: Date?)
    /// The last turn ended, or none has started.
    case betweenTurns

    /// Looked for before a line is parsed. Text that only mentions one, such as a command's output, holds it inside
    /// a JSON string, where its quotes are escaped, so it never matches.
    static let turnEventMarkers: [Data] = ["task_started", "task_complete", "turn_aborted"]
        .map { Data(#""type":"\#($0)""#.utf8) }

    private static let newline = UInt8(ascii: "\n")

    /// The state a turn event leaves the session in; nil for any other line.
    init?(turnEventLine line: Data) {
        guard let object = ConversationMetadata.object(from: line),
              object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any] else { return nil }
        switch payload["type"] as? String {
        case "task_started": self = .inTurn(startedAt: ConversationMetadata.date(object["timestamp"]))
        case "task_complete", "turn_aborted": self = .betweenTurns
        default: return nil
        }
    }

    /// The state after the last turn event in `text`, which holds whole lines; nil when it has none.
    static func afterLastTurnEvent(in text: Data) -> CodexTurnState? {
        var searchEnd = text.endIndex
        while searchEnd > text.startIndex {
            let searchRange = text.startIndex..<searchEnd
            guard let markerRange = turnEventMarkers
                .compactMap({ text.range(of: $0, options: .backwards, in: searchRange) })
                .max(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
            let lineStart = text[..<markerRange.lowerBound].lastIndex(of: newline).map { $0 + 1 } ?? text.startIndex
            let lineEnd = text[markerRange.upperBound...].firstIndex(of: newline) ?? text.endIndex
            if let state = CodexTurnState(turnEventLine: Data(text[lineStart..<lineEnd])) { return state }
            searchEnd = lineStart
        }
        return nil
    }
}
