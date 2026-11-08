import Foundation

/// The tmux commands that find text in a tmux session's history with copy mode's own search, which highlights the
/// matches and scrolls the selected one into view, and what they print. tmux finds the text as typed, with no patterns.
/// It ignores the case of A to Z only in text without a capital one, and matches other letters as typed, so the search
/// is for the text with A to Z made lowercase, and ignores their case as the terminal's own find does. Each search
/// leaves copy mode's cursor at the start of the selected match, in emacs and vi `mode-keys` alike:
///
/// - Backward search selects the nearest match that starts before the cursor, so from a match's start it moves to the
///   one printed before it, wrapping from the oldest to the newest (`wrap-search`, on by default).
/// - Forward search from a match's start selects that match in emacs keys and the next one in vi keys, and leaves the
///   cursor past that match's end in emacs keys. So twice forward, then once back, selects the next newer match in
///   either.
///
/// tmux counts every match only for the first search of a copy mode or a search for other text; a search for the same
/// text again counts only the screen's and keeps the count it had. Any copy mode command but a search drops the count,
/// so no other command comes between a search's steps, and a new search leaves copy mode and enters it again first.
enum TmuxHistorySearchCommands {
    /// Prints the matches tmux counted, and 1 when it stopped counting before the last, after a word that tells the
    /// line from what an SSH host's startup files print.
    static let countMarker = "justsessions-find-count"
    static let countFormat = "\(countMarker) #{search_count} #{search_count_partial}"

    /// Starts a search for the newest match, from the end of the last line, whether or not a search runs already.
    static func startingSearch(for query: String, inSession sessionName: String) -> [String] {
        let pane = paneTarget(sessionName)
        return ["if-shell", "-F", "-t", pane, "#{pane_in_mode}", "send-keys -t \(pane) -X cancel", ";"]
            + ["copy-mode", "-t", pane, ";"]
            + copyModeCommand("history-bottom", pane: pane) + [";"]
            + copyModeCommand("end-of-line", pane: pane) + [";"]
            + searchCommand("search-backward-text", for: query, pane: pane) + [";"]
            + printingCount(pane: pane)
    }

    static func movingSearch(_ direction: TerminalFindDirection, for query: String, inSession sessionName: String) -> [String] {
        let pane = paneTarget(sessionName)
        let backward = searchCommand("search-backward-text", for: query, pane: pane)
        let forward = searchCommand("search-forward-text", for: query, pane: pane)
        let moves = switch direction {
        case .towardOlder: backward
        case .towardNewer: forward + [";"] + forward + [";"] + backward
        }
        return moves + [";"] + printingCount(pane: pane)
    }

    /// Leaves copy mode, which takes the highlight away and shows the shell's screen again.
    static func endingSearch(inSession sessionName: String) -> [String] {
        copyModeCommand("cancel", pane: paneTarget(sessionName))
    }

    /// Nil for output without the count's line, as when tmux could not run the search. The total is nil when tmux kept
    /// no count, as after a key you pressed in copy mode took the search's highlight away.
    static func printedCount(inOutput output: String) -> (total: Int?, isPartial: Bool)? {
        guard let line = output.split(whereSeparator: \.isNewline).last(where: { $0.hasPrefix(countMarker) }) else { return nil }
        let fields = line.dropFirst(countMarker.count).split(separator: " ")
        guard let total = fields.first.flatMap({ Int($0) }) else { return (nil, false) }
        return (total, fields.count > 1 && fields[1] == "1")
    }

    /// `=name:` is exactly that session's pane; a bare `=name` is no pane, and a plain name could match another
    /// session whose name starts with it.
    private static func paneTarget(_ sessionName: String) -> String {
        "=\(sessionName):"
    }

    private static func copyModeCommand(_ command: String, argument: String? = nil, pane: String) -> [String] {
        ["send-keys", "-t", pane, "-X", command] + (argument.map { [ThisMacTmuxServer.escapingCommandSeparator($0)] } ?? [])
    }

    private static func searchCommand(_ command: String, for query: String, pane: String) -> [String] {
        copyModeCommand(command, argument: lowercasingAToZ(query), pane: pane)
    }

    static func lowercasingAToZ(_ text: String) -> String {
        let capitals: ClosedRange<Unicode.Scalar> = "A"..."Z"
        let scalars = text.unicodeScalars.map { capitals.contains($0) ? Unicode.Scalar($0.value + 32)! : $0 }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func printingCount(pane: String) -> [String] {
        ["display-message", "-p", "-t", pane, countFormat]
    }
}
