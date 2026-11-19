import AppKit
import Foundation
import Testing

@testable import JustSessions

/// A ⌘-click on a link a CLI broke over rows opens all of it in a Ghostty tab whose process draws the screen; see
/// `GhosttyTabTerminalView+HardWrappedLinks`. The URL runs to the last column, and the rest follows on the next row
/// after two cells, as Claude Code lays out a reply.
@MainActor
@Suite(.serialized)
struct GhosttyTabHardWrappedLinkTests {
    /// As tmux draws a CLI's screen: on the alternate screen, moving the cursor to each row, with the next row's
    /// indentation left as empty cells. No mouse reporting, so the alternate screen alone has to count.
    @Test(arguments: [0, 1])
    func aCommandClickOnEitherRowOfTheAlternateScreenOpensTheWholeURL(row: Int) async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        var openedLinks: [String] = []
        fixture.view.onOpenLink = { openedLinks.append($0) }
        try await fixture.start(printing: "wait_for screen-written; cat screen")
        let grid = TerminalTestGrid(try #require(fixture.view.gridMetrics), scale: fixture.window.backingScaleFactor)
        let url = Self.longURL(for: grid)
        let firstRowPart = url.prefix(grid.columns - 4)
        let screen =
            "\u{1B}[?1049h\u{1B}[2J\u{1B}[1;1HSee \(firstRowPart)"
            + "\u{1B}[2;3H\(url.dropFirst(firstRowPart.count)) for it\u{1B}[4;1HREADY"
        try screen.write(to: fixture.folder.appendingPathComponent("screen"), atomically: true, encoding: .utf8)
        fixture.signal("screen-written")
        try await expectEventually { fixture.screen.contains("READY") }

        try TerminalClick.click(fixture.view, column: 6, row: row, in: grid, modifierFlags: .command)

        #expect(openedLinks == [url])
    }

    /// The bundled tmux, which `make test` hands the tests, draws a program's lines in the tab, with mouse reporting
    /// on as in every CLI tab on this Mac. tmux is the tab's process, so it reads Ghostty's answers to its queries as
    /// in the app. Skipped without the bundled tmux.
    @Test(arguments: [0, 1])
    func aCommandClickOnEitherRowOfALineTmuxDrewOpensTheWholeURL(row: Int) async throws {
        guard let runtime = ProcessInfo.processInfo.environment["JUSTSESSIONS_TEST_TMUX_RUNTIME"] else { return }
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        let tmux = "\(runtime)/bin/tmux"
        // A socket path has to stay short, so it sits right in the temporary folder.
        let socket = FileManager.default.temporaryDirectory.appendingPathComponent("tmux-\(UUID().uuidString.prefix(8))").path
        defer { _ = BoundedProcessRunner.output(ofExecutable: tmux, arguments: ["-S", socket, "kill-server"], timeout: 5) }
        var openedLinks: [String] = []
        fixture.view.onOpenLink = { openedLinks.append($0) }
        fixture.view.startProcess(
            executable: "/bin/sh",
            args: [
                "-c",
                """
                while [ ! -e lines-written ]; do sleep 0.02; done
                exec "$0" -S "$1" -f /dev/null new-session 'cat lines; sleep 600' \\; set -g mouse on \\; set -g status off
                """, tmux, socket,
            ],
            environment: ["HOME=\(fixture.folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"],
            execName: nil,
            currentDirectory: fixture.folder.path
        )
        try await fixture.waitForLayout()
        let grid = TerminalTestGrid(try #require(fixture.view.gridMetrics), scale: fixture.window.backingScaleFactor)
        let url = Self.longURL(for: grid)
        let firstRowPart = url.prefix(grid.columns - 4)
        let lines = "See \(firstRowPart)\r\n  \(url.dropFirst(firstRowPart.count)) for it\r\nREADY"
        try lines.write(to: fixture.folder.appendingPathComponent("lines"), atomically: true, encoding: .utf8)
        fixture.signal("lines-written")
        try await expectEventually { fixture.screen.contains("READY") }
        try await expectEventually { fixture.view.terminalSurface?.isMouseCaptured == true }

        try TerminalClick.click(fixture.view, column: 6, row: row, in: grid, modifierFlags: .command)

        #expect(openedLinks == [url])
    }

    /// Longer than a row, so it has to be broken.
    private static func longURL(for grid: TerminalTestGrid) -> String {
        "https://example.com/" + String(repeating: "x", count: grid.columns) + "/end"
    }
}
