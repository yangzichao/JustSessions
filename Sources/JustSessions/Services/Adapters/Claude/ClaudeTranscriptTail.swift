import Foundation

/// What the last lines of a Claude Code transcript say about its session, found without reading the whole file.
struct ClaudeTranscriptTail {
    static let maximumByteCount = 262_144

    /// The `timestamp` of the last line that has one.
    private(set) var latestTimestamp: Date?
    /// The title from the last `custom-title` line that has one.
    private(set) var latestCustomTitle: String?

    init(file: URL) {
        self.init(lines: JSONLinesReader.trailingLines(in: file, maximumByteCount: Self.maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file.
    init(lines: [Data]) {
        for line in lines.reversed() {
            guard let record = ConversationMetadata.object(from: line) else { continue }
            if latestTimestamp == nil {
                latestTimestamp = ConversationMetadata.date(record["timestamp"])
            }
            if latestCustomTitle == nil, record["type"] as? String == "custom-title" {
                latestCustomTitle = record["customTitle"] as? String
            }
            if latestTimestamp != nil, latestCustomTitle != nil { break }
        }
    }
}
