import Foundation

/// The fields Kiro CLI writes first in a session's `<id>.json`. A large `session_state` object follows them, so
/// only the start of the file is read when it holds them.
struct KiroSessionMetadata: Equatable {
    static let maximumHeadByteCount = 65_536

    let sessionID: String
    let projectPath: String
    let title: String?
    let updatedAt: Date?
    /// Why the session was made, such as `subagent` for one another session started.
    let createdReason: String?

    init?(object: [String: Any]) {
        guard let sessionID = object["session_id"] as? String,
              let projectPath = object["cwd"] as? String else { return nil }
        self.sessionID = sessionID
        self.projectPath = projectPath
        self.title = object["title"] as? String
        self.updatedAt = ConversationMetadata.date(object["updated_at"])
        self.createdReason = object["session_created_reason"] as? String
    }

    init?(file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: Self.maximumHeadByteCount) else { return nil }
        if let object = Self.objectBeforeSessionState(in: head), object["session_id"] != nil {
            self.init(object: object)
        } else if head.count < Self.maximumHeadByteCount {
            // That was the whole file.
            guard let object = ConversationMetadata.object(from: head) else { return nil }
            self.init(object: object)
        } else {
            // The fields come after `session_state`, or the start holds no `session_state`: read it all.
            guard let rest = try? handle.readToEnd(), let object = ConversationMetadata.object(from: head + rest) else { return nil }
            self.init(object: object)
        }
    }

    /// The object's members up to `session_state`, closed into an object of their own. Nil when `session_state`
    /// is not in `data` as a member of the outer object.
    static func objectBeforeSessionState(in data: Data) -> [String: Any]? {
        let key = Data(#""session_state""#.utf8)
        var searchStart = data.startIndex
        while let keyRange = data.range(of: key, in: searchStart..<data.endIndex) {
            searchStart = keyRange.upperBound
            // A member name follows `{` or `,`. Inside a string, the quote would be escaped instead.
            guard let previous = data[..<keyRange.lowerBound].last(where: { !isJSONWhitespace($0) }),
                  previous == UInt8(ascii: ",") || previous == UInt8(ascii: "{") else { continue }
            var members = Data(data[..<keyRange.lowerBound])
            while let last = members.last, isJSONWhitespace(last) || last == UInt8(ascii: ",") { members.removeLast() }
            members.append(UInt8(ascii: "}"))
            if let object = ConversationMetadata.object(from: members) { return object }
        }
        return nil
    }

    private static func isJSONWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
    }
}
