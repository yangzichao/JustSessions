import Foundation
import Testing
@testable import JustSessions

/// ⌘F in a plain terminal's tmux session against the installed tmux, in a sandbox server; see `ThisMacTmuxSandbox`.
/// A host's own tmux may use vi keys in copy mode, so both kinds run.
@MainActor
struct TmuxHistoryFindSandboxTests {
    @Test(arguments: ["emacs", "vi"])
    func findsEveryMatchInTheHistoryAndMovesBetweenThemInOrder(modeKeys: String) async throws {
        guard let session = try await FindSandboxSession.start(modeKeys: modeKeys) else { return }
        defer { session.sandbox.tearDown() }
        let finder = TmuxHistoryFinder(history: .onThisMac(sessionName: session.name, server: session.sandbox.server))
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }
        func expectSelected(_ number: Int, onLine line: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(
                reports.last == TerminalFindMatchCount(total: 3, selectedNumber: number, exceedsCountLimit: false),
                sourceLocation: sourceLocation
            )
            // In tmux 3.6a, unlike 3.7c, the top line also has copy mode's position on its right.
            #expect(session.paneValue("#{copy_cursor_line}").hasPrefix(line), sourceLocation: sourceLocation)
        }

        _ = finder.findText("NEEDLE")
        try await expectEventually { reports.count == 1 }
        expectSelected(1, onLine: "Needle 3")
        let steps: [(TerminalFindDirection, Int, String)] = [
            (.towardOlder, 2, "needle 2"),
            (.towardOlder, 3, "needle 1"),
            (.towardOlder, 1, "Needle 3"),
            (.towardNewer, 3, "needle 1"),
            (.towardNewer, 2, "needle 2"),
        ]
        for (direction, number, line) in steps {
            let reportCount = reports.count
            _ = finder.findTextAgain("NEEDLE", direction: direction)
            try await expectEventually { reports.count == reportCount + 1 }
            expectSelected(number, onLine: line)
        }

        finder.endTextFind()
        #expect(await session.sandbox.waitUntil { session.paneValue("#{pane_in_mode}") == "0" })
    }

    /// A new search while one runs counts again, rather than keeping the old count. Case counts only for letters
    /// beyond A to Z.
    @Test func aNewSearchCountsAgainAndLettersBeyondAToZMatchAsTyped() async throws {
        guard let session = try await FindSandboxSession.start(modeKeys: "emacs") else { return }
        defer { session.sandbox.tearDown() }
        let finder = TmuxHistoryFinder(history: .onThisMac(sessionName: session.name, server: session.sandbox.server))
        var reports: [TerminalFindMatchCount?] = []
        finder.onStepFinished = { reports.append($0) }

        _ = finder.findText("École")
        try await expectEventually { reports.count == 1 }
        #expect(reports.last == TerminalFindMatchCount(total: 1, selectedNumber: 1, exceedsCountLimit: false))

        _ = finder.findText("absent")
        try await expectEventually { reports.count == 2 }
        #expect(reports.last == TerminalFindMatchCount.none)
    }
}

/// A detached tmux session whose output put two of its three matches above the screen, in the history only.
@MainActor
private struct FindSandboxSession {
    let sandbox: ThisMacTmuxSandbox
    let name: String

    static func start(modeKeys: String) async throws -> FindSandboxSession? {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return nil }
        let name = TmuxSessionName.forNewPlainTerminal()
        let output = "echo needle 1; echo école; seq 1 100; echo needle 2; echo École; seq 1 100; echo Needle 3; seq 1 5; exec sleep 600"
        _ = sandbox.tmuxOutput([
            "-f", "/dev/null", "new-session", "-d", "-s", name, "-x", "80", "-y", "24", "/bin/sh", "-c", output, ";",
            "set-option", "-wg", "mode-keys", modeKeys,
        ])
        let printedEverything = await sandbox.waitUntil {
            sandbox.tmuxOutput(["capture-pane", "-p", "-t", "=\(name):"]).contains("Needle 3")
        }
        if !printedEverything { sandbox.tearDown() }
        try #require(printedEverything, "tmux sessions: \(sandbox.server.sessionNames())")
        return FindSandboxSession(sandbox: sandbox, name: name)
    }

    func paneValue(_ format: String) -> String {
        sandbox.tmuxOutput(["display-message", "-p", "-t", "=\(name):", format]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
