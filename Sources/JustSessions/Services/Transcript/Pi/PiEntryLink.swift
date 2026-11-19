import Foundation

struct PiEntryLink: Equatable {
    let lineIndex: Int
    let id: String?
    let parentID: String?
    let mightBeShown: Bool
}

extension PiEntryLink {
    private static let headByteCount = 512

    init?(line: Data, lineIndex: Int, decoder: JSONDecoder = JSONDecoder()) {
        if let link = Self.linkFromLineHead(line, lineIndex: lineIndex) {
            self = link
            return
        }
        guard let record = try? decoder.decode(PiEntryLinkRecord.self, from: line),
            let entryType = record.type,
            entryType != "session"
        else { return nil }
        self.init(
            lineIndex: lineIndex,
            id: record.id,
            parentID: record.parentID,
            mightBeShown: Self.mightShow(line, entryType: entryType, role: record.message?.role)
        )
    }

    private static func mightShow(_ line: Data, entryType: String, role: String?) -> Bool {
        PiPreviewedEntry(entryType: entryType, role: role)?.mightBeShown(in: line) ?? false
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
            scanner.skip(",\"parentId\":")
        else { return nil }
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
                let value = scanner.plainString()
            else { return nil }
            role = value
        }
        return PiEntryLink(
            lineIndex: lineIndex,
            id: id,
            parentID: parentID,
            mightBeShown: mightShow(line, entryType: entryType, role: role)
        )
    }
}
