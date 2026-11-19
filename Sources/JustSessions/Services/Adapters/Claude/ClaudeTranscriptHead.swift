import Foundation

/// What the first lines of a Claude Code transcript say about its session. Reading stops at `maximumByteCount`
/// bytes, or as soon as the working directory, first prompt, and a custom title are all known. After
/// `maximumLineCount` lines it goes on only until the first prompt is found, and reads only `user` lines: a session
/// that opens with slash commands, such as `/model`, has its first prompt further down. The byte limit allows for a
/// first prompt sent with screenshots, which runs to megabytes: the bookkeeping lines Claude Code writes before it
/// name no folder, so a limit that cuts the prompt off would leave the session unlisted.
struct ClaudeTranscriptHead: Sendable, Codable {
    static let maximumByteCount = 8 << 20
    static let maximumLineCount = 30
    private static let userKey = Data(#""user""#.utf8)

    private(set) var workingDirectory: String?
    /// What the user typed in the first user message that holds a prompt; see `ClaudeUserPromptText`. A message
    /// Claude Code wrote for the user is not one: a slash command, its output, or a line marked `isMeta`.
    private(set) var firstPrompt: String?
    private(set) var customTitle: String?
    private(set) var aiTitle: String?
    private(set) var isSidechain = false

    init(file: URL) {
        var head = ClaudeTranscriptHead()
        var lineCount = 0
        JSONLinesReader.forEachLeadingLine(in: file, maximumByteCount: Self.maximumByteCount) { line in
            lineCount += 1
            head.read(line, pastLineLimit: lineCount > Self.maximumLineCount)
            return head.wantsLine(after: lineCount)
        }
        self = head
    }

    init(lines: [Data]) {
        for (index, line) in lines.enumerated() {
            read(line, pastLineLimit: index >= Self.maximumLineCount)
            if !wantsLine(after: index + 1) { break }
        }
    }

    private init() {}

    private var isComplete: Bool {
        workingDirectory != nil && firstPrompt != nil && customTitle != nil
    }

    private func wantsLine(after lineCount: Int) -> Bool {
        !isComplete && (lineCount < Self.maximumLineCount || firstPrompt == nil)
    }

    private mutating func read(_ line: Data, pastLineLimit: Bool) {
        if pastLineLimit, line.range(of: Self.userKey) == nil { return }
        guard let record = ConversationMetadata.object(from: line) else { return }
        workingDirectory = workingDirectory ?? record["cwd"] as? String
        isSidechain = isSidechain || record["isSidechain"] as? Bool == true
        if record["type"] as? String == "custom-title" {
            customTitle = record["customTitle"] as? String
        }
        if record["type"] as? String == "ai-title", let title = record["aiTitle"] as? String {
            aiTitle = title
        }
        if firstPrompt == nil, record["isMeta"] as? Bool != true,
            let text = ClaudeUserPromptText.text(ofRecord: record), ConversationMetadata.holdsTitle(text)
        {
            firstPrompt = text
        }
    }
}
