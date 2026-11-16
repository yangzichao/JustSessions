import Darwin
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

    static func firstLine(of file: URL, maxBytes: Int = 65_536, requiresRegularFile: Bool = false) -> [String: Any]? {
        let handle: FileHandle
        if requiresRegularFile {
            // Checking the URL then opening it can still block if a file is replaced by a FIFO between those calls.
            let descriptor = open(file.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW)
            guard descriptor >= 0 else { return nil }
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
                close(descriptor)
                return nil
            }
            handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        } else {
            guard let opened = try? FileHandle(forReadingFrom: file) else { return nil }
            handle = opened
        }
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
        guard let firstLine = rawTitle.flatMap(firstNonBlankLine(of:)), !firstLine.hasPrefix("<") else { return fallback }
        return String(firstLine.prefix(maximumTitleLength))
    }

    /// Stops at the first line with text, since a prompt can run to hundreds of kilobytes of pasted text.
    private static func firstNonBlankLine(of text: String) -> String? {
        let scalars = text.unicodeScalars
        var lineStart = scalars.startIndex
        while lineStart < scalars.endIndex {
            let lineEnd = scalars[lineStart...].firstIndex(where: CharacterSet.newlines.contains) ?? scalars.endIndex
            let line = String(Substring(scalars[lineStart..<lineEnd])).trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { return line }
            guard lineEnd < scalars.endIndex else { return nil }
            lineStart = scalars.index(after: lineEnd)
        }
        return nil
    }
}
