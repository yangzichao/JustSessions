import Foundation

/// Each session's text in a file of its own under Caches, so a search after a relaunch reads only the sessions that
/// changed. A Codex session's text can be saved with where a read can resume, so a read after the CLI appends parses
/// only the session's end. The cache is disposable: a file that can't be read, or was saved by another format, reads as
/// missing, and one saved for another state of its session is only resumed from once its resume state checks out.
struct SessionMessageTextCache: Sendable {
    /// Goes up when what is saved changes, such as which entries are kept, so text saved before is read again. 2: smaller
    /// Codex pages, which merge fewer tool calls into one entry, and a header with where a Codex read can resume.
    /// 3: file identity distinguishes timestamp-preserving replacements from unchanged transcripts.
    static let formatVersion = 3
    /// How long the text of a session no longer listed is kept. A session can be missing from the list only for now,
    /// such as one on an SSH host not refreshed yet since launch, so its text is not deleted right away.
    static let unlistedRetention: TimeInterval = 30 * 24 * 60 * 60

    let directory: URL

    static let standard = SessionMessageTextCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("SessionMessages", isDirectory: true)
    )

    /// Saved text a Codex read can resume from once its session grows.
    struct ResumableText: Sendable {
        let text: SessionMessageText
        let state: SessionMessageTextResumeState
    }

    enum Lookup: Sendable {
        /// Saved for the session as it is.
        case current(SessionMessageText)
        /// Saved for an earlier state of the session, so the session has changed since it was read; with the text when
        /// it was saved with a resume state.
        case changed(ResumableText?)
        /// Never saved, or saved for another session, by another format, or unreadable.
        case missing
    }

    /// What a saved file starts with, after `magic` and the header's length. It is small, so a file saved for another
    /// state of its session or by another format is turned down without decoding its text, which follows it.
    private struct Header: Codable {
        let version: Int
        let conversationID: String
        let fingerprint: SessionMessageTextFingerprint
        let resumeState: SessionMessageTextResumeState?
    }

    private static let magic = Data("JSMSGTXT".utf8)
    private static let maximumHeaderByteCount = 1 << 20

    func lookup(for conversationID: String, fingerprint: SessionMessageTextFingerprint) -> Lookup {
        guard let handle = try? FileHandle(forReadingFrom: file(for: conversationID)) else { return .missing }
        defer { try? handle.close() }
        guard let header = try? Self.header(from: handle), header.version == Self.formatVersion,
              header.conversationID == conversationID else { return .missing }
        if header.fingerprint == fingerprint {
            return (try? Self.text(from: handle)).map(Lookup.current) ?? .missing
        }
        guard let state = header.resumeState, header.fingerprint.sourceFilePath == fingerprint.sourceFilePath,
              let text = try? Self.text(from: handle), state.isConsistent(with: text) else { return .changed(nil) }
        return .changed(ResumableText(text: text, state: state))
    }

    func text(for conversationID: String, fingerprint: SessionMessageTextFingerprint) -> SessionMessageText? {
        guard case .current(let text) = lookup(for: conversationID, fingerprint: fingerprint) else { return nil }
        return text
    }

    /// Saves the text and its resume state in one file, replaced at once, so a reader never sees one without the other.
    func save(
        _ text: SessionMessageText, resumeState: SessionMessageTextResumeState? = nil,
        for conversationID: String, fingerprint: SessionMessageTextFingerprint
    ) {
        let header = Header(version: Self.formatVersion, conversationID: conversationID, fingerprint: fingerprint, resumeState: resumeState)
        guard let headerData = try? JSONEncoder().encode(header), let textData = try? JSONEncoder().encode(text) else { return }
        var data = Self.magic
        withUnsafeBytes(of: UInt32(headerData.count).bigEndian) { data.append(contentsOf: $0) }
        data.append(headerData)
        data.append(textData)
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

    private static func header(from handle: FileHandle) throws -> Header {
        let lengthByteCount = MemoryLayout<UInt32>.size
        guard let start = try handle.read(upToCount: magic.count + lengthByteCount), start.count == magic.count + lengthByteCount,
              start.prefix(magic.count) == magic else { throw CocoaError(.fileReadCorruptFile) }
        let headerByteCount = start.suffix(lengthByteCount).reduce(0) { $0 << 8 | Int($1) }
        guard headerByteCount <= maximumHeaderByteCount, let headerData = try handle.read(upToCount: headerByteCount),
              headerData.count == headerByteCount else { throw CocoaError(.fileReadCorruptFile) }
        return try JSONDecoder().decode(Header.self, from: headerData)
    }

    /// The text after the header `handle` has just read.
    private static func text(from handle: FileHandle) throws -> SessionMessageText {
        try JSONDecoder().decode(SessionMessageText.self, from: handle.readToEnd() ?? Data())
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
