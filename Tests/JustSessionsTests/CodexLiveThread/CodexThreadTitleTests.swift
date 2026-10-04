import Foundation
import Testing
@testable import JustSessions

struct CodexThreadTitleTests {
    private static let threadID = "01a10846-4c77-75e2-bec8-ab638c1d2e3f"

    @Test func readsTheStartOfTheThreadIDThatCodexCutsWithAnEllipsis() {
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "01a10846-4c77-75e2-bec8-ab638...") == "01a10846-4c77-75e2-bec8-ab638")
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: "01A10846-4C77-75E2-BEC8-AB638…") == "01a10846-4c77-75e2-bec8-ab638")
    }

    @Test func readsAWholeThreadID() {
        #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: Self.threadID) == Self.threadID)
    }

    @Test func otherTitlesNameNoThread() {
        for title in [
            "",
            "增强按钮点击反馈 | JustSessions",
            "Zichaos-MacBook-Pro.local",
            "01a10846-4c77-75e2-bec8-ab638... | JustSessions",
            // Too short to name one thread.
            "01a10846-4c77-75e2...",
            // Neither cut nor whole.
            "01a10846-4c77-75e2-bec8-ab638",
            // Not shaped like an id.
            "01a10846x4c77-75e2-bec8-ab638...",
            "01a10846-4c77-75e2-bec8-zz638...",
        ] {
            #expect(CodexThreadTitle.threadIDPrefix(inTerminalTitle: title) == nil, "\(title)")
        }
    }

    @Test func launchArgumentsAskCodexForTheThreadIDInTheTitle() {
        #expect(CodexThreadTitle.launchArguments == ["-c", #"tui.terminal_title=["thread-id"]"#])
    }
}
