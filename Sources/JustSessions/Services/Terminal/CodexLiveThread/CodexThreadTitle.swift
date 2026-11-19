import Foundation

/// Codex runs its threads in a background server that its CLIs share, so the CLI's own process holds no rollout file
/// open, and a rollout does not say which CLI writes it. Launched with `launchArguments`, the title's last item, after
/// ` | `, is the thread's id, cut to its first 29 characters and `...`. It changes as soon as `/new`, `/clear`,
/// `/resume`, or `/fork` moves the CLI to another thread; a thread that `/new` starts gets its rollout file with the
/// first prompt. While Codex names the thread, a spinner frame follows the id.
///
/// Codex ignores a setting it does not know, and warns once about a title item it does not know: `thread-id` came in
/// 0.131, `run-state` in 0.124, and `activity` in 0.128.
enum CodexThreadTitle {
    static let launchArguments = ["-c", #"tui.terminal_title=["activity","run-state","thread-id"]"#]
    static let minimumThreadIDPrefixLength = 24
    private static let threadIDShape = Array("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")

    static func threadIDPrefix(inTerminalTitle title: String) -> String? {
        let lastItem = title.components(separatedBy: " | ").last ?? title
        let trimmedTitle = String(lastItem.split(whereSeparator: \.isWhitespace).first ?? "").lowercased()
        if ConversationProvider.codex.isValidSessionID(trimmedTitle) { return trimmedTitle }
        guard
            let prefix = ["...", "…"].lazy.compactMap({ ellipsis in
                trimmedTitle.hasSuffix(ellipsis) ? String(trimmedTitle.dropLast(ellipsis.count)) : nil
            }).first,
            (minimumThreadIDPrefixLength..<threadIDShape.count).contains(prefix.count),
            zip(prefix, threadIDShape).allSatisfy(matchesThreadIDShape)
        else { return nil }
        return prefix
    }

    private static func matchesThreadIDShape(_ character: Character, _ shape: Character) -> Bool {
        shape == "-" ? character == "-" : character.isHexDigit
    }
}
