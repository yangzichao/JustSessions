import Foundation

/// What the last lines of a Claude Code transcript say about its session, found without reading the whole file.
struct ClaudeTranscriptTail: Sendable, Codable {
    static let maximumByteCount = 262_144
    /// Bytes every `relocated` line holds. Once the timestamp and title are known, only lines holding them are parsed.
    private static let relocatedWorkingDirectoryKey = Data(#""relocatedCwd""#.utf8)
    /// Bytes every assistant line holds, with the model that wrote it.
    private static let modelKey = Data(#""model""#.utf8)
    /// Bytes every `ai-title` line holds.
    private static let aiTitleKey = Data(#""aiTitle""#.utf8)
    /// Bytes every `worktree-state` line holds.
    private static let worktreeStateKey = Data(#""worktree-state""#.utf8)

    /// The `timestamp` of the last line that has one.
    private(set) var latestTimestamp: Date?
    /// The title from the last `custom-title` line that has one.
    private(set) var latestCustomTitle: String?
    /// The title from the last `ai-title` line: the one Claude Code generates for a session, and rewrites as the
    /// session goes on.
    private(set) var latestAITitle: String?
    /// The `relocatedCwd` of the last `relocated` line: the folder `/cd`, or entering or leaving a git worktree, moved
    /// the session to. Claude Code moves the transcript into that folder's project directory and reads the session's
    /// folder from here, ahead of any `cwd`, which also changes whenever its shell changes directory.
    private(set) var relocatedWorkingDirectory: String?
    /// The `message.model` of the last assistant line that names a model, `<synthetic>` left out.
    private(set) var latestModel: String?
    /// The git worktree the session entered last, the `worktreeSession.worktreePath` of the last `worktree-state` line
    /// that has one; nil when the session entered none. A line without a `worktreeSession` says the session is in no
    /// worktree now: Claude Code writes one as the session leaves its worktree, with a `relocated` line for the
    /// folder it goes back to, and one alone when it resumes a session whose worktree was removed.
    private(set) var worktreeDirectory: String?
    /// The folder the session entered that worktree from, its `worktreeSession.originalCwd`: the repository's.
    private(set) var worktreeRepositoryDirectory: String?

    /// The folder a session that moved is listed under and resumed in, ahead of any `cwd`. A session whose last move
    /// was into a git worktree belongs to the repository it entered the worktree from: `/resume` in Claude Code lists
    /// it there, and resuming it from the repository returns it to its worktree, or keeps it in the repository once
    /// the worktree is removed. Leaving the worktree, or a `/cd` from it, moves the session to another folder.
    var movedProjectDirectory: String? {
        if let worktreeRepositoryDirectory,
            relocatedWorkingDirectory == nil || relocatedWorkingDirectory == worktreeDirectory
        {
            return worktreeRepositoryDirectory
        }
        return relocatedWorkingDirectory
    }

    init(file: URL) {
        self.init(lines: JSONLinesReader.trailingLines(in: file, maximumByteCount: Self.maximumByteCount))
    }

    /// `lines` are oldest first, as they are in the file.
    init(lines: [Data]) {
        for line in lines.reversed() {
            if latestTimestamp != nil, latestCustomTitle != nil,
                latestAITitle != nil || line.range(of: Self.aiTitleKey) == nil,
                line.range(of: Self.relocatedWorkingDirectoryKey) == nil,
                worktreeDirectory != nil || line.range(of: Self.worktreeStateKey) == nil,
                latestModel != nil || line.range(of: Self.modelKey) == nil
            {
                continue
            }
            guard let record = ConversationMetadata.object(from: line) else { continue }
            if latestTimestamp == nil {
                latestTimestamp = ConversationMetadata.date(record["timestamp"])
            }
            if latestCustomTitle == nil, record["type"] as? String == "custom-title" {
                latestCustomTitle = record["customTitle"] as? String
            }
            if latestAITitle == nil, record["type"] as? String == "ai-title" {
                latestAITitle = record["aiTitle"] as? String
            }
            if relocatedWorkingDirectory == nil, record["type"] as? String == "relocated" {
                relocatedWorkingDirectory = record["relocatedCwd"] as? String
            }
            if worktreeDirectory == nil, record["type"] as? String == "worktree-state",
                let worktree = record["worktreeSession"] as? [String: Any]
            {
                worktreeDirectory = worktree["worktreePath"] as? String
                worktreeRepositoryDirectory = worktree["originalCwd"] as? String
            }
            if latestModel == nil, record["type"] as? String == "assistant" {
                latestModel = SessionModel(id: (record["message"] as? [String: Any])?["model"] as? String)?.id
            }
            if latestTimestamp != nil, latestCustomTitle != nil, relocatedWorkingDirectory != nil, worktreeDirectory != nil,
                latestModel != nil
            {
                break
            }
        }
    }
}
