import Foundation

/// What the first lines of a Claude Code transcript say about its session. Reading stops after `maximumLineCount`
/// lines, at `maximumByteCount` bytes, or as soon as the working directory, first prompt, and a custom title are all
/// known. The limit allows for a first prompt sent with screenshots, which runs to megabytes: the bookkeeping lines
/// Claude Code writes before it name no folder, so a limit that cuts the prompt off would leave the session unlisted.
struct ClaudeTranscriptHead: Sendable, Codable {
    static let maximumByteCount = 8 << 20
    static let maximumLineCount = 30

    /// The first `cwd` a line records.
    private(set) var workingDirectory: String?
    /// What the user typed in the first user message that holds a prompt; see `ClaudeUserPromptText`.
    private(set) var firstPrompt: String?
    private(set) var customTitle: String?
    /// Whether a line read is marked `isSidechain`.
    private(set) var isSidechain = false

    /// Reads only as far as needed, so a transcript is never loaded whole.
    init(file: URL) {
        var head = ClaudeTranscriptHead()
        var lineCount = 0
        JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: Self.maximumByteCount) { line in
            lineCount += 1
            head.read(line)
            return !head.isComplete && lineCount < Self.maximumLineCount
        }
        self = head
    }

    /// `lines` are oldest first, as they are in the file.
    init(lines: [Data]) {
        for line in lines.prefix(Self.maximumLineCount) {
            read(line)
            if isComplete { break }
        }
    }

    private init() {}

    private var isComplete: Bool {
        workingDirectory != nil && firstPrompt != nil && customTitle != nil
    }

    private mutating func read(_ line: Data) {
        guard let record = ConversationMetadata.object(from: line) else { return }
        workingDirectory = workingDirectory ?? record["cwd"] as? String
        isSidechain = isSidechain || record["isSidechain"] as? Bool == true
        if record["type"] as? String == "custom-title" {
            customTitle = record["customTitle"] as? String
        }
        if firstPrompt == nil {
            firstPrompt = ClaudeUserPromptText.text(ofRecord: record)
        }
    }
}
