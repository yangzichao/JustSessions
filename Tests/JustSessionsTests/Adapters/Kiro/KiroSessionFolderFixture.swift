import Foundation

/// Kiro CLI's `sessions/cli` folder: `<id>.json` metadata beside `<id>.jsonl` messages.
struct KiroSessionFolderFixture {
    let sessionsDirectory: URL

    func writeSession(
        id sessionID: String,
        projectPath: String,
        title: String? = nil,
        createdReason: String? = nil,
        updatedAt: String = "2026-09-30T10:00:00.000Z",
        messageLines: [String]
    ) throws {
        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        var members = [#""session_id":"\#(sessionID)""#, #""cwd":"\#(projectPath)""#, #""updated_at":"\#(updatedAt)""#]
        if let title { members.append(#""title":"\#(title)""#) }
        if let createdReason { members.append(#""session_created_reason":"\#(createdReason)""#) }
        members.append(#""session_state":{"conversation":{"history":[{"title":"not the session's"}]}}"#)
        try "{\(members.joined(separator: ","))}".write(
            to: sessionsDirectory.appendingPathComponent("\(sessionID).json"),
            atomically: true,
            encoding: .utf8
        )
        try messageLines.map { $0 + "\n" }.joined().write(
            to: sessionsDirectory.appendingPathComponent("\(sessionID).jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func prompt(_ text: String) -> String {
        #"{"version":"v1","kind":"Prompt","data":{"message_id":"m1","content":[{"kind":"text","data":"\#(text)"}]}}"#
    }

    static let reply = #"{"version":"v1","kind":"AssistantMessage","data":{"message_id":"m2","content":[{"kind":"text","data":"Sure"}]}}"#
}
