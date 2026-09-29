import Foundation

/// One entry of Claude Code's live process registry, `~/.claude/sessions/<pid>.json`.
/// The file format belongs to Claude Code, so every field is read defensively.
struct ClaudeLiveSessionRecord: Sendable, Equatable {
    static let maximumWaitReasonLength = 60

    let sessionID: String
    /// Set only when the user chose the name, e.g. with `/rename`.
    let userChosenName: String?
    /// What the CLI is doing, from `status`; nil for a status this app does not know.
    let activity: CLIActivity?

    init?(jsonData: Data) {
        guard let object = ConversationMetadata.object(from: jsonData),
              let sessionID = object["sessionId"] as? String,
              ConversationMetadata.isValidSessionID(sessionID) else { return nil }
        self.sessionID = sessionID
        self.userChosenName = Self.userChosenName(from: object)
        self.activity = Self.activity(from: object)
    }

    /// `/rename` marks the name with `nameSource` "user"; derived or unmarked names are not a deliberate title.
    private static func userChosenName(from object: [String: Any]) -> String? {
        guard object["nameSource"] as? String == "user" else { return nil }
        let cleanedName = ConversationMetadata.cleanTitle(object["name"] as? String, fallback: "")
        return cleanedName.isEmpty ? nil : cleanedName
    }

    /// Claude Code writes `status` "busy" while it works on a turn, and "waiting" while something such as a
    /// permission prompt waits on you, with `waitingFor` saying what, such as "input needed". Between turns it writes
    /// "idle", or "shell" while a shell command it started in the background still runs.
    private static func activity(from object: [String: Any]) -> CLIActivity? {
        switch object["status"] as? String {
        case "busy":
            return .working
        case "waiting":
            let reason = (object["waitingFor"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .needsInput(reason: reason.isEmpty ? nil : String(reason.prefix(maximumWaitReasonLength)))
        case "idle", "shell":
            return .idle
        default:
            return nil
        }
    }
}
