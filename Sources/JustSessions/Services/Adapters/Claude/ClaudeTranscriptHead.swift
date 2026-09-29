import Foundation

/// What the first lines of a Claude Code transcript say about its session. Only the first `maximumByteCount` bytes
/// are read, and reading stops after `maximumLineCount` lines or as soon as the working directory, first prompt, and a
/// custom title are all known.
struct ClaudeTranscriptHead {
    static let maximumByteCount = 131_072
    static let maximumLineCount = 30

    /// The first `cwd` a line records.
    private(set) var workingDirectory: String?
    /// The first user message sent as plain text.
    private(set) var firstPrompt: String?
    private(set) var customTitle: String?
    /// Whether a line read is marked `isSidechain`.
    private(set) var isSidechain = false

    init(file: URL) {
        self.init(lines: JSONLinesReader.leadingLines(in: file, maximumByteCount: Self.maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file.
    init(lines: [Data]) {
        for line in lines.prefix(Self.maximumLineCount) {
            guard let record = ConversationMetadata.object(from: line) else { continue }
            workingDirectory = workingDirectory ?? record["cwd"] as? String
            isSidechain = isSidechain || record["isSidechain"] as? Bool == true
            if record["type"] as? String == "custom-title" {
                customTitle = record["customTitle"] as? String
            }
            if firstPrompt == nil, record["type"] as? String == "user",
               let message = record["message"] as? [String: Any] {
                firstPrompt = message["content"] as? String
            }
            if workingDirectory != nil, firstPrompt != nil, customTitle != nil { break }
        }
    }
}
