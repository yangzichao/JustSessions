import Testing
@testable import JustSessions

struct TmuxHistorySearchCommandsTests {
    private let sessionName = "justsessions-terminal-a1b2c3d4"

    /// A search already under way is left first, so tmux counts every match again.
    @Test func aNewSearchEntersCopyModeAgainAndSearchesBackFromTheEnd() {
        let pane = "=justsessions-terminal-a1b2c3d4:"

        let arguments = TmuxHistorySearchCommands.startingSearch(for: "needle", inSession: sessionName)

        #expect(arguments == [
            "if-shell", "-F", "-t", pane, "#{pane_in_mode}", "send-keys -t \(pane) -X cancel", ";",
            "copy-mode", "-t", pane, ";",
            "send-keys", "-t", pane, "-X", "history-bottom", ";",
            "send-keys", "-t", pane, "-X", "end-of-line", ";",
            "send-keys", "-t", pane, "-X", "search-backward-text", "needle", ";",
            "display-message", "-p", "-t", pane, TmuxHistorySearchCommands.countFormat,
        ])
    }

    @Test func movingTowardOlderSearchesBackOnce() {
        let pane = "=justsessions-terminal-a1b2c3d4:"

        let arguments = TmuxHistorySearchCommands.movingSearch(.towardOlder, for: "needle", inSession: sessionName)

        #expect(arguments == [
            "send-keys", "-t", pane, "-X", "search-backward-text", "needle", ";",
            "display-message", "-p", "-t", pane, TmuxHistorySearchCommands.countFormat,
        ])
    }

    /// Twice forward, then back, lands on the next newer match in emacs and vi keys alike.
    @Test func movingTowardNewerSearchesForwardTwiceThenBack() {
        let pane = "=justsessions-terminal-a1b2c3d4:"

        let arguments = TmuxHistorySearchCommands.movingSearch(.towardNewer, for: "needle", inSession: sessionName)

        #expect(arguments == [
            "send-keys", "-t", pane, "-X", "search-forward-text", "needle", ";",
            "send-keys", "-t", pane, "-X", "search-forward-text", "needle", ";",
            "send-keys", "-t", pane, "-X", "search-backward-text", "needle", ";",
            "display-message", "-p", "-t", pane, TmuxHistorySearchCommands.countFormat,
        ])
    }

    /// tmux would end the command at a trailing semicolon and run the rest as a command of its own.
    @Test func aQueryEndingInASemicolonStaysTheSearchsText() {
        let arguments = TmuxHistorySearchCommands.startingSearch(for: "a;", inSession: sessionName)

        #expect(arguments.contains("a\\;"))
        #expect(!arguments.contains("a;"))
    }

    /// tmux would match case for text with a capital letter, and matches letters beyond A to Z as typed.
    @Test func searchesForTheTextWithAToZLowercase() {
        #expect(TmuxHistorySearchCommands.lowercasingAToZ("Needle ÉCOLE Zz") == "needle École zz")
        let arguments = TmuxHistorySearchCommands.movingSearch(.towardNewer, for: "NeedLe", inSession: sessionName)
        #expect(arguments.filter { $0 == "needle" }.count == 3)
        #expect(!arguments.contains("NeedLe"))
    }

    @Test func endingLeavesCopyMode() {
        #expect(TmuxHistorySearchCommands.endingSearch(inSession: sessionName)
            == ["send-keys", "-t", "=justsessions-terminal-a1b2c3d4:", "-X", "cancel"])
    }

    @Test func readsTheCountAfterWhatTheHostPrintedFirst() throws {
        let counted = try #require(TmuxHistorySearchCommands.printedCount(inOutput: "Welcome to devbox\njustsessions-find-count 12 0\n"))
        #expect(counted.total == 12)
        #expect(!counted.isPartial)

        let partial = try #require(TmuxHistorySearchCommands.printedCount(inOutput: "justsessions-find-count 1000 1"))
        #expect(partial.total == 1000)
        #expect(partial.isPartial)
    }

    @Test func anEmptyCountHasNoTotal() throws {
        let printed = try #require(TmuxHistorySearchCommands.printedCount(inOutput: "justsessions-find-count  \n"))

        #expect(printed.total == nil)
        #expect(!printed.isPartial)
    }

    @Test func outputWithoutTheCountsLineIsNoCount() {
        #expect(TmuxHistorySearchCommands.printedCount(inOutput: "") == nil)
        #expect(TmuxHistorySearchCommands.printedCount(inOutput: "no server running on /tmp/tmux-501/justsessions\n") == nil)
    }
}
