import Foundation

/// Each session's text in a file of its own under Caches, so a search after a relaunch reads only the sessions that
/// changed. The cache is disposable: a file that can't be read, or was saved for another state of its session or by
/// another format, reads as missing.
struct SessionMessageTextCache: Sendable {
    /// Goes up when what is saved changes, such as which entries are kept, so text saved before is read again.
    static let formatVersion = 1
    /// How long the text of a session no longer listed is kept. A session can be missing from the list only for now,
    /// such as one on an SSH host not refreshed yet since launch, so its text is not deleted right away.
    static let unlistedRetention: TimeInterval = 30 * 24 * 60 * 60

    let directory: URL

    static let standard = SessionMessageTextCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("SessionMessages", isDirectory: true)
    )

    private struct SavedText: Codable {
        let version: Int
        let conversationID: String
        let fingerprint: SessionMessageTextFingerprint
        let text: SessionMessageText
    }

    func text(for conversationID: String, fingerprint: SessionMessageTextFingerprint) -> SessionMessageText? {
        guard let data = try? Data(contentsOf: file(for: conversationID)),
              let saved = try? JSONDecoder().decode(SavedText.self, from: data),
              saved.version == Self.formatVersion, saved.conversationID == conversationID,
              saved.fingerprint == fingerprint else { return nil }
        return saved.text
    }

    func save(_ text: SessionMessageText, for conversationID: String, fingerprint: SessionMessageTextFingerprint) {
        let saved = SavedText(version: Self.formatVersion, conversationID: conversationID, fingerprint: fingerprint, text: text)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file(for: conversationID), options: .atomic)
    }

    /// Deletes the saved text of sessions other than `listedConversationIDs` once it has gone unsaved for
    /// `unlistedRetention`, such as that of deleted sessions or of a removed SSH host's.
    func removeText(ofSessionsOtherThan listedConversationIDs: Set<String>, now: Date = .now) {
        let listedFileNames = Set(listedConversationIDs.map(Self.fileName(for:)))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        for file in files where !listedFileNames.contains(file.lastPathComponent) {
            let savedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(savedAt) > Self.unlistedRetention { try? FileManager.default.removeItem(at: file) }
        }
    }

    private func file(for conversationID: String) -> URL {
        directory.appendingPathComponent(Self.fileName(for: conversationID))
    }

    /// The session's ID with every character but ASCII letters, digits, `-`, `_`, and `.` percent-encoded, so the `:`,
    /// `@`, and spaces in IDs never reach a file name.
    private static func fileName(for conversationID: String) -> String {
        (conversationID.addingPercentEncoding(withAllowedCharacters: fileNameCharacters) ?? conversationID) + ".json"
    }

    private static let fileNameCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )
}
