import Foundation

/// The Claude registry record and latest custom-title line relayed from the host, base64-encoded independently so
/// quotes, Unicode, terminal escapes, and tmux format expressions in a name stay data. Activity remains in its own
/// option too, for the no-tab reader and sessions started by an older app. No registry file on this Mac is read for an
/// SSH tab.
enum RemoteClaudeSessionTitle {
    static let optionName = "@justsessions-claude-session"
    static let titlePrefix = "justsessions-claude:"
    static let titleFormat = "#{?\(optionName),\(titlePrefix)#{\(optionName)},\(RemoteCLIActivityTitle.titleFormat)}"
    /// A malformed or unexpectedly large host record tells nothing, rather than turning the title into a transcript.
    static let maximumPayloadLength = 32768

    static func record(inTerminalTitle title: String) -> ClaudeLiveSessionRecord? {
        guard title.hasPrefix(titlePrefix), title.utf8.count <= maximumPayloadLength else { return nil }
        let parts = title.dropFirst(titlePrefix.count).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let data = Data(base64Encoded: String(parts[0])),
            let record = ClaudeLiveSessionRecord(jsonData: data)
        else { return nil }
        // Some Claude versions omit the chosen name in the registry. Back it up with the transcript's explicit
        // custom-title line, but only for this same session: /clear must never bring the old session's line along.
        // A registry that names the session wins over an older transcript line cached before a turn.
        guard record.userChosenName == nil,
            let titleData = Data(base64Encoded: String(parts[1])),
            let titleLine = ConversationMetadata.object(from: titleData),
            titleLine["type"] as? String == "custom-title",
            titleLine["sessionId"] as? String == record.sessionID,
            let name = titleLine["customTitle"] as? String,
            !ConversationMetadata.cleanTitle(name, fallback: "").isEmpty,
            var object = ConversationMetadata.object(from: data)
        else { return record }
        object["name"] = name
        object["nameSource"] = "user"
        guard let renamed = try? JSONSerialization.data(withJSONObject: object) else { return record }
        return ClaudeLiveSessionRecord(jsonData: renamed)
    }
}
