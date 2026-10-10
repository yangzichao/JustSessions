import AppKit
import Darwin
import Foundation
import Testing
@testable import JustSessions

/// A tab's process runs the same way whichever engine draws its terminal: on a pseudo-terminal of the app's, as the
/// app's child, with its output on screen, its terminal's size, its title on the tab, and its exit status.
@MainActor
struct TabTerminalLifecycleTests {
    @Test(arguments: TerminalEngine.allCases)
    func theProcessStartsAndItsOutputReachesTheTerminal(_ engine: TerminalEngine) async throws {
        let fixture = try TabTerminalFixture(engine: engine, script: "echo OUTPUT_FROM_THE_PROCESS; exec sleep 30")
        defer { fixture.tearDown() }

        fixture.tab.startIfNeeded()

        #expect(fixture.tab.processID > 0)
        try await expectEventually(timeout: .seconds(30)) { fixture.screen.contains("OUTPUT_FROM_THE_PROCESS") }
    }

    @Test(arguments: TerminalEngine.allCases)
    func resizingTheTerminalResizesTheProcesssPseudoTerminal(_ engine: TerminalEngine) async throws {
        // Reports its terminal's size as `SIZE:<rows> <columns>;` at the start and on each SIGWINCH.
        let fixture = try TabTerminalFixture(engine: engine, script: """
            report() { printf 'SIZE:%s;\\n' "$(stty size)"; }
            trap report WINCH
            report
            while :; do sleep 0.1; done
            """)
        defer { fixture.tearDown() }
        fixture.tab.startIfNeeded()
        try await expectEventually(timeout: .seconds(30)) { fixture.reportedSize != nil && fixture.reportedSize == fixture.terminalSize }
        let sizeBefore = try #require(fixture.reportedSize)

        fixture.window.setContentSize(NSSize(width: 500, height: 300))

        try await expectEventually(timeout: .seconds(30)) {
            fixture.reportedSize != sizeBefore && fixture.reportedSize == fixture.terminalSize
        }
    }

    @Test(arguments: TerminalEngine.allCases)
    func theProcesssExitStatusReachesTheTab(_ engine: TerminalEngine) async throws {
        let fixture = try TabTerminalFixture(engine: engine, script: "exit 3")
        defer { fixture.tearDown() }

        fixture.tab.startIfNeeded()

        try await expectEventually(timeout: .seconds(30)) { fixture.tab.hasExited }
        #expect(fixture.tab.exitCode == 3)
    }

    @Test(arguments: TerminalEngine.allCases)
    func theTitleTheProcessSetsReachesTheTab(_ engine: TerminalEngine) async throws {
        let fixture = try TabTerminalFixture(engine: engine, script: "printf '\\033]2;%s\\007' 'Title from the CLI'; exec sleep 30")
        defer { fixture.tearDown() }

        fixture.tab.startIfNeeded()

        try await expectEventually(timeout: .seconds(30)) { fixture.tab.terminalTitle == "Title from the CLI" }
    }

    @Test(arguments: TerminalEngine.allCases)
    func closingTheTabHangsUpOnTheProcessAndReapsIt(_ engine: TerminalEngine) async throws {
        // Ignores SIGTERM, the signal `terminate()` sends, so only the SIGHUP of closing ends it.
        let fixture = try TabTerminalFixture(engine: engine, script: "trap '' TERM; echo READY; while :; do sleep 0.1; done")
        defer { fixture.tearDown() }
        fixture.tab.startIfNeeded()
        let processID = fixture.tab.processID
        try #require(processID > 0)
        try await expectEventually(timeout: .seconds(30)) { fixture.screen.contains("READY") }

        fixture.tab.close()

        // `kill(pid, 0)` still succeeds for a zombie, so it fails only once the process has ended and been reaped.
        try await expectEventually(timeout: .seconds(30)) { kill(processID, 0) != 0 }
    }
}

/// A tab running `/bin/sh -c script` in a window of its own, which a Ghostty terminal needs to show anything.
@MainActor
private final class TabTerminalFixture {
    let tab: TerminalSession
    let window: NSWindow
    private let folder: URL

    init(engine: TerminalEngine, script: String) throws {
        _ = NSApplication.shared
        folder = try makeTemporaryDirectory()
        tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: nil,
            projectPath: folder.path,
            action: nil,
            displayTitle: "Terminal",
            command: NativeCLICommand(
                executablePath: "/bin/sh",
                arguments: ["-c", script],
                workingDirectory: folder.path,
                environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"]
            )
        )
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
    }

    var screen: String { screenText(of: tab.terminalView) }

    /// The last size the process reported, as `stty size` prints it: rows, then columns.
    var reportedSize: TerminalGridSize? {
        guard let report = screen.components(separatedBy: "SIZE:").last(where: { $0.contains(";") }),
              let numbers = report.split(separator: ";").first?.split(separator: " "),
              numbers.count == 2, let rows = Int(numbers[0]), let columns = Int(numbers[1]) else { return nil }
        return TerminalGridSize(rows: rows, columns: columns)
    }

    /// The grid the terminal lays its text out at: SwiftTerm's, or the viewport Ghostty last reported.
    var terminalSize: TerminalGridSize? {
        switch tab.terminalView {
        case let swiftTermView as SelectableTerminalView:
            let terminal = swiftTermView.getTerminal()
            return TerminalGridSize(rows: terminal.rows, columns: terminal.cols)
        case let ghosttyView as GhosttyTabTerminalView:
            guard let viewport = ghosttyView.viewport else { return nil }
            return TerminalGridSize(rows: Int(viewport.rows), columns: Int(viewport.columns))
        default:
            return nil
        }
    }

    func tearDown() {
        tab.close()
        window.close()
        try? FileManager.default.removeItem(at: folder)
    }
}

private struct TerminalGridSize: Equatable {
    let rows: Int
    let columns: Int
}
