import Foundation

/// One entry of Claude Code's live process registry, `~/.claude/sessions/<pid>.json`.
/// The file format belongs to Claude Code, so every field is read defensively.
struct ClaudeLiveSessionRecord: Sendable, Equatable {
    let sessionID: String
    /// Set only when the user chose the name, e.g. with `/rename`.
    let userChosenName: String?

    init?(jsonData: Data) {
        guard let object = ConversationMetadata.object(from: jsonData),
              let sessionID = object["sessionId"] as? String,
              ConversationMetadata.isValidSessionID(sessionID) else { return nil }
        self.sessionID = sessionID
        self.userChosenName = Self.userChosenName(from: object)
    }

    /// `/rename` marks the name with `nameSource` "user"; derived or unmarked names are not a deliberate title.
    private static func userChosenName(from object: [String: Any]) -> String? {
        guard object["nameSource"] as? String == "user" else { return nil }
        let cleanedName = ConversationMetadata.cleanTitle(object["name"] as? String, fallback: "")
        return cleanedName.isEmpty ? nil : cleanedName
    }
}
