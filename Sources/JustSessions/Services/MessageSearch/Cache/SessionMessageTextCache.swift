import Foundation

struct SessionMessageTextCache: Sendable {
    static let formatVersion = 3
    static let unlistedRetention: TimeInterval = 30 * 24 * 60 * 60

    let directory: URL

    static let standard = SessionMessageTextCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("SessionMessages", isDirectory: true)
    )

    struct ResumableText: Sendable {
        let text: SessionMessageText
        let state: SessionMessageTextResumeState
    }

    enum Lookup: Sendable {
        case current(SessionMessageText)
        case changed(ResumableText?)
        case missing
    }

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
            header.conversationID == conversationID
        else { return .missing }
        if header.fingerprint == fingerprint {
            return (try? Self.text(from: handle)).map(Lookup.current) ?? .missing
        }
        guard let state = header.resumeState, header.fingerprint.sourceFilePath == fingerprint.sourceFilePath,
            let text = try? Self.text(from: handle), state.isConsistent(with: text)
        else { return .changed(nil) }
        return .changed(ResumableText(text: text, state: state))
    }

    func text(for conversationID: String, fingerprint: SessionMessageTextFingerprint) -> SessionMessageText? {
        guard case .current(let text) = lookup(for: conversationID, fingerprint: fingerprint) else { return nil }
        return text
    }

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

    func removeText(ofSessionsOtherThan listedConversationIDs: Set<String>, now: Date = .now) {
        let listedFileNames = Set(listedConversationIDs.map(Self.fileName(for:)))
        guard
            let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else { return }
        for file in files where !listedFileNames.contains(file.lastPathComponent) {
            let savedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(savedAt) > Self.unlistedRetention { try? FileManager.default.removeItem(at: file) }
        }
    }

    private static func header(from handle: FileHandle) throws -> Header {
        let lengthByteCount = MemoryLayout<UInt32>.size
        guard let start = try handle.read(upToCount: magic.count + lengthByteCount), start.count == magic.count + lengthByteCount,
            start.prefix(magic.count) == magic
        else { throw CocoaError(.fileReadCorruptFile) }
        let headerByteCount = start.suffix(lengthByteCount).reduce(0) { $0 << 8 | Int($1) }
        guard headerByteCount <= maximumHeaderByteCount, let headerData = try handle.read(upToCount: headerByteCount),
            headerData.count == headerByteCount
        else { throw CocoaError(.fileReadCorruptFile) }
        return try JSONDecoder().decode(Header.self, from: headerData)
    }

    private static func text(from handle: FileHandle) throws -> SessionMessageText {
        try JSONDecoder().decode(SessionMessageText.self, from: handle.readToEnd() ?? Data())
    }

    private func file(for conversationID: String) -> URL {
        directory.appendingPathComponent(Self.fileName(for: conversationID))
    }

    private static func fileName(for conversationID: String) -> String {
        (conversationID.addingPercentEncoding(withAllowedCharacters: fileNameCharacters) ?? conversationID) + ".json"
    }

    private static let fileNameCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )
}
