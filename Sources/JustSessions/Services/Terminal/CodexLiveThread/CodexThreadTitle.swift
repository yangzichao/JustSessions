import Foundation

/// The thread a Codex CLI is in, as its terminal title names it. Codex runs its threads in a background server that
/// its CLIs share, so the CLI's own process holds no rollout file open, and a rollout does not say which CLI writes
/// it. Launched with `launchArguments`, the title is the thread's id, cut to its first 29 characters and `...`. It
/// changes as soon as `/new`, `/clear`, `/resume`, or `/fork` moves the CLI to another thread; a thread that `/new`
/// starts gets its rollout file with the first prompt.
///
/// Codex ignores a setting it does not know, so a Codex without this one titles the terminal as before.
enum CodexThreadTitle {
    static let launchArguments = ["-c", #"tui.terminal_title=["thread-id"]"#]
    /// A shorter start of an id could belong to more than one thread.
    static let minimumThreadIDPrefixLength = 24
    private static let threadIDShape = Array("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")

    /// The id, or the start of it, of the thread a Codex terminal title names; nil for any other title.
    static func threadIDPrefix(inTerminalTitle title: String) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces).lowercased()
        if ConversationProvider.codex.isValidSessionID(trimmedTitle) { return trimmedTitle }
        guard let prefix = ["...", "…"].lazy.compactMap({ ellipsis in
            trimmedTitle.hasSuffix(ellipsis) ? String(trimmedTitle.dropLast(ellipsis.count)) : nil
        }).first,
            (minimumThreadIDPrefixLength..<threadIDShape.count).contains(prefix.count),
            zip(prefix, threadIDShape).allSatisfy(matchesThreadIDShape) else { return nil }
        return prefix
    }

    private static func matchesThreadIDShape(_ character: Character, _ shape: Character) -> Bool {
        shape == "-" ? character == "-" : character.isHexDigit
    }
}
