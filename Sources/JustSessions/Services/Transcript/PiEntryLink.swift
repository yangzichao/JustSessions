import Foundation

/// What the preview learns about one line of a Pi session before decoding it: where the line is, how its entry links
/// into the session's tree, and whether it could show anything.
struct PiEntryLink: Equatable {
    private static let shownEntryTypes: Set<String> = ["message", "compaction", "branch_summary"]
    private static let shownMessageRoles: Set<String> = ["user", "assistant", "bashExecution"]
    /// Enough of a line for its type, id, parent, timestamp, and message role.
    private static let headByteCount = 512

    /// Counts the file's non-empty lines from zero.
    let lineIndex: Int
    /// Nil in version 1 sessions, which list entries in order without linking them.
    let id: String?
    /// Nil for an entry that starts the tree, and in version 1 sessions.
    let parentID: String?
    /// False for entries the preview never shows, such as tool results and model changes, so they are not decoded.
    let mightBeShown: Bool

    init(lineIndex: Int, id: String?, parentID: String?, mightBeShown: Bool) {
        self.lineIndex = lineIndex
        self.id = id
        self.parentID = parentID
        self.mightBeShown = mightBeShown
    }

    /// Nil for the session header and for lines that are not entries.
    init?(line: Data, lineIndex: Int) {
        if let link = Self.linkFromLineHead(line, lineIndex: lineIndex) {
            self = link
            return
        }
        guard let record = ConversationMetadata.object(from: line),
              let entryType = record["type"] as? String,
              entryType != "session" else { return nil }
        self.init(
            lineIndex: lineIndex,
            id: record["id"] as? String,
            parentID: record["parentId"] as? String,
            mightBeShown: Self.mightBeShown(
                entryType: entryType,
                role: (record["message"] as? [String: Any])?["role"] as? String
            )
        )
    }

    /// Reads the start of a line without JSON parsing, which matters because tool results make up most of a
    /// session's bytes. Only Pi's own layout is judged this way:
    /// `{"type":"…","id":"…","parentId":…,"timestamp":"…","message":{"role":"…"`, where everything from `timestamp`
    /// on is needed only for messages. Any other line, or one cut off before its closing brace, is parsed instead.
    private static func linkFromLineHead(_ line: Data, lineIndex: Int) -> PiEntryLink? {
        guard line.last == UInt8(ascii: "}") else { return nil }
        var scanner = PiLineHeadScanner(bytes: Array(line.prefix(headByteCount)))
        guard scanner.skip("{\"type\":\""),
              let entryType = scanner.plainString(),
              scanner.skip(",\"id\":\""),
              let id = scanner.plainString(),
              scanner.skip(",\"parentId\":") else { return nil }
        let parentID: String?
        if scanner.skip("null") {
            parentID = nil
        } else if scanner.skip("\""), let value = scanner.plainString() {
            parentID = value
        } else {
            return nil
        }

        var role: String?
        if entryType == "message" {
            guard scanner.skip(",\"timestamp\":\""),
                  scanner.plainString() != nil,
                  scanner.skip(",\"message\":{\"role\":\""),
                  let value = scanner.plainString() else { return nil }
            role = value
        }
        return PiEntryLink(
            lineIndex: lineIndex,
            id: id,
            parentID: parentID,
            mightBeShown: mightBeShown(entryType: entryType, role: role)
        )
    }

    private static func mightBeShown(entryType: String, role: String?) -> Bool {
        guard entryType == "message" else { return shownEntryTypes.contains(entryType) }
        return role.map(shownMessageRoles.contains) ?? false
    }
}
