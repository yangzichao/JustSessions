import Foundation

/// The fields Kiro CLI writes first in a session's `<id>.json`. A large `session_state` object follows them, so
/// only the start of the file is read when it holds them.
struct KiroSessionMetadata: Equatable {
    static let maximumHeadByteCount = 65_536

    let sessionID: String
    let projectPath: String
    let title: String?
    let updatedAt: Date?
    /// Why the session was made. Kiro CLI 2.16 writes `subagent` for every session its terminal UI starts, the main one
    /// included, since the UI runs the chat as an ACP agent (`kiro-cli-chat acp`), so this doesn't tell a subagent's apart.
    let createdReason: String?
    /// The session that started this one, for a subagent's, a tangent's, or a rewind's; nil for a main session.
    let parentSessionID: String?

    init?(object: [String: Any]) {
        guard let sessionID = object["session_id"] as? String,
            let projectPath = object["cwd"] as? String
        else { return nil }
        self.sessionID = sessionID
        self.projectPath = projectPath
        self.title = object["title"] as? String
        self.updatedAt = ConversationMetadata.date(object["updated_at"])
        self.createdReason = object["session_created_reason"] as? String
        self.parentSessionID = (object["parent_session_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    init?(file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: Self.maximumHeadByteCount) else { return nil }
        let headIsWholeFile = head.count < Self.maximumHeadByteCount
        if headIsWholeFile {
            guard let object = ConversationMetadata.object(from: head) else { return nil }
            self.init(object: object)
        } else if let leadingMembers = Self.objectOfMembersBeforeSessionState(in: head), Self.namesEveryReadMember(leadingMembers) {
            self.init(object: leadingMembers)
        } else {
            guard let rest = try? handle.readToEnd(), let object = ConversationMetadata.object(from: head + rest) else { return nil }
            self.init(object: object)
        }
    }

    private static let readMemberNames = ["session_id", "cwd", "title", "updated_at", "session_created_reason", "parent_session_id"]

    private static func namesEveryReadMember(_ object: [String: Any]) -> Bool {
        readMemberNames.allSatisfy { object[$0] != nil }
    }

    static func objectOfMembersBeforeSessionState(in data: Data) -> [String: Any]? {
        let key = Data(#""session_state""#.utf8)
        var searchStart = data.startIndex
        while let keyRange = data.range(of: key, in: searchStart..<data.endIndex) {
            searchStart = keyRange.upperBound
            guard couldStartMemberName(at: keyRange.lowerBound, in: data) else { continue }
            if let object = ConversationMetadata.object(from: objectClosing(membersBefore: keyRange.lowerBound, in: data)) {
                return object
            }
        }
        return nil
    }

    private static func couldStartMemberName(at index: Data.Index, in data: Data) -> Bool {
        let previous = data[..<index].last(where: { !isJSONWhitespace($0) })
        return previous == UInt8(ascii: ",") || previous == UInt8(ascii: "{")
    }

    private static func objectClosing(membersBefore index: Data.Index, in data: Data) -> Data {
        var members = Data(data[..<index])
        while let last = members.last, isJSONWhitespace(last) || last == UInt8(ascii: ",") { members.removeLast() }
        members.append(UInt8(ascii: "}"))
        return members
    }

    private static func isJSONWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
    }
}
