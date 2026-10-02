import Foundation

/// What the preview learns about one line of a Pi session before decoding it: where the line is, how its entry links
/// into the session's tree, and whether it could show anything.
struct PiEntryLink: Equatable {
    /// Counts the file's non-empty lines from zero.
    let lineIndex: Int
    /// Nil in version 1 sessions, which list entries in order without linking them.
    let id: String?
    /// Nil for an entry that starts the tree, and in version 1 sessions.
    let parentID: String?
    /// False for entries the preview never shows, such as tool results and model changes, so they are not decoded.
    let mightBeShown: Bool
}

extension PiEntryLink {
    /// Enough of a line for its type, id, parent, timestamp, and message role.
    private static let headByteCount = 512

    /// Nil for the session header and for lines that are not entries. `decoder` parses a line not in Pi's own
    /// layout, so a reader going through many lines can share one.
    init?(line: Data, lineIndex: Int, decoder: JSONDecoder = JSONDecoder()) {
        if let link = Self.linkFromLineHead(line, lineIndex: lineIndex) {
            self = link
            return
        }
        guard let record = try? decoder.decode(PiEntryLinkRecord.self, from: line),
              let entryType = record.type,
              entryType != "session" else { return nil }
        self.init(
            lineIndex: lineIndex,
            id: record.id,
            parentID: record.parentID,
            mightBeShown: PiPreviewedEntry(entryType: entryType, role: record.message?.role) != nil
        )
    }

    /// Reads the start of a line without JSON parsing, which matters because tool results make up most of a
    /// session's bytes. Only Pi's own layout is judged this way:
    /// `{"type":"…","id":"…","parentId":…,"timestamp":"…","message":{"role":"…"`, where everything from `timestamp`
    /// on is needed only for messages. Any other line, or one cut off before its closing brace, is parsed instead.
    private static func linkFromLineHead(_ line: Data, lineIndex: Int) -> PiEntryLink? {
        guard line.last == UInt8(ascii: "}") else { return nil }
        var scanner = PiLineHeadScanner(line: line, byteLimit: headByteCount)
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
            mightBeShown: PiPreviewedEntry(entryType: entryType, role: role) != nil
        )
    }
}
