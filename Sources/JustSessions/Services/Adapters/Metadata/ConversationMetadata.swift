import Foundation

enum ConversationMetadata {
    /// Title of a session whose first prompt is not known yet.
    static let untitledConversationTitle = "Untitled conversation"
    static let maximumTitleLength = 120

    static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        return ISO8601TimestampParser.shared.date(from: text)
    }

    static func object(from line: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: line) as? [String: Any]
    }

    static func firstLine(of file: URL, maxBytes: Int = 65_536) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes),
              let newline = data.firstIndex(of: UInt8(ascii: "\n")) else { return nil }
        return object(from: Data(data[..<newline]))
    }

    static func fileModificationDate(_ file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    static func isValidSessionID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    /// The first non-blank line of a prompt, or `fallback` when there is none or it is markup the CLI injected
    /// (such as `<command-name>`) rather than something the user typed.
    static func cleanTitle(_ rawTitle: String?, fallback: String) -> String {
        let firstLine = rawTitle?
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let firstLine, !firstLine.hasPrefix("<") else { return fallback }
        return String(firstLine.prefix(maximumTitleLength))
    }
}
