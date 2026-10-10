import AppKit
import Foundation
import Testing
@testable import JustSessions

/// How a Ghostty tab hands its process's output to Ghostty: no faster than Ghostty parses it, in order, all of it
/// before the tab hears the process ended, and gathered while the tab is hidden, as a SwiftTerm tab does.
@MainActor
@Suite(.serialized)
struct GhosttyTabOutputTests {
    /// While the main thread can't pass output on, the tab stops reading once 4 MiB waits, so a process that writes
    /// faster blocks, as it would in a SwiftTerm tab; once the main thread is free again, the rest of the output comes.
    @Test func aFastProcessBlocksWhileItsOutputWaitsUnparsed() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.setWorkspaceActive(false)
        let total = 16 << 20
        try await fixture.start(printing: Self.producer(writing: total))

        // The main thread is busy, as when it draws or lays out for a long time.
        let written = Self.bytesWrittenOnceTheProcessStops(in: fixture)

        let limit = GhosttyOutputBackpressure.defaultHighWaterByteCount
        #expect(written > 0)
        #expect(written < limit + (2 << 20), "The process wrote \(written) bytes")
        #expect(fixture.view.outputBackpressure.unparsedByteCount < limit + (256 << 10))
        fixture.view.setWorkspaceActive(true)
        try await expectEventually(timeout: .seconds(60)) { fixture.screen.contains("PRODUCER-DONE") }
        #expect(Self.progress(in: fixture) >= total)
    }

    /// Small limits, so the reading stops and starts many times on the way.
    @Test func everyLineArrivesInOrderAcrossPauses() async throws {
        let fixture = try GhosttyTabFixture(outputHighWaterByteCount: 4 << 10, outputLowWaterByteCount: 1 << 10)
        defer { fixture.tearDown() }
        let count = 3000
        try await fixture.start(printing: """
            i=1; while [ $i -le \(count) ]; do printf '%d\\r\\n' $i; i=$((i+1)); done; printf 'NUMBERS-DONE'
            """)
        Self.blockMainThread(for: 0.5)

        try await expectEventually(timeout: .seconds(60)) { fixture.screen.contains("NUMBERS-DONE") }

        let numbers = try #require(fixture.selectAllText())
            .split(whereSeparator: \.isNewline)
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        #expect(numbers == Array(1...count))
    }

    /// The last output a hidden tab gathered reaches Ghostty before the tab hears the process ended.
    @Test func theExitIsReportedAfterTheLastOutput() async throws {
        _ = NSApplication.shared
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let tab = TerminalSession(
            engine: .ghostty,
            conversation: nil,
            provider: nil,
            projectPath: folder.path,
            action: nil,
            displayTitle: "Terminal",
            command: NativeCLICommand(
                executablePath: "/bin/sh",
                arguments: ["-c", "printf 'FIRST\\r\\n'; sleep 0.5; printf 'LAST-OUTPUT'; sleep 0.05"],
                workingDirectory: folder.path,
                environment: ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"]
            )
        )
        let view = try #require(tab.terminalView as? GhosttyTabTerminalView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer {
            tab.close()
            window.close()
        }
        view.setWorkspaceActive(false)
        var screenWhenTheProcessEnded: String?
        tab.onProcessFinished = {
            view.inMemorySession.waitForPendingOutput()
            screenWhenTheProcessEnded = view.inMemorySession.readViewportText()
        }

        tab.startIfNeeded()

        try await expectEventually(timeout: .seconds(30)) { tab.hasExited }
        #expect(screenWhenTheProcessEnded?.contains("LAST-OUTPUT") == true, "\(screenWhenTheProcessEnded ?? "nil")")
    }

    /// A hidden tab gathers output, as a SwiftTerm tab does, and passes it on before it resizes or shows.
    @Test func aHiddenTabPassesGatheredOutputOnBeforeResizingAndShowing() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.setWorkspaceActive(false)
        try await fixture.start(printing: "wait_for one; printf 'BEFORE-RESIZE\\r\\n'; wait_for two; printf 'BEFORE-SHOWING'")

        fixture.signal("one")
        try await Self.gatherOutput(in: fixture)
        #expect(!fixture.screen.contains("BEFORE-RESIZE"))
        fixture.view.setFrameSize(NSSize(width: 600, height: 380))
        fixture.view.inMemorySession.waitForPendingOutput()
        #expect(fixture.screen.contains("BEFORE-RESIZE"))

        fixture.signal("two")
        try await Self.gatherOutput(in: fixture)
        #expect(!fixture.screen.contains("BEFORE-SHOWING"))
        fixture.view.setWorkspaceActive(true)
        fixture.view.inMemorySession.waitForPendingOutput()
        #expect(fixture.screen.contains("BEFORE-SHOWING"))
    }

    /// Waits, with the main thread blocked, until the process's output is on its way, then lets the hidden tab take
    /// it in, well before its next 8 Hz pass would pass it on. The test goes on first even if the main thread is busy
    /// for longer, since its wake-up is queued on the main thread before that pass.
    private static func gatherOutput(in fixture: GhosttyTabFixture) async throws {
        try #require(waitForOutputOnItsWay(in: fixture))
        try await Task.sleep(for: .milliseconds(20))
        fixture.view.inMemorySession.waitForPendingOutput()
    }

    private static func waitForOutputOnItsWay(in fixture: GhosttyTabFixture) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 30)
        while fixture.view.outputBackpressure.unparsedByteCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.005)
        }
        return fixture.view.outputBackpressure.unparsedByteCount > 0
    }

    /// As when the main thread draws or lays out for a long time.
    private static func blockMainThread(for seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Writes `total` bytes of lines in 64 KiB writes, then `PRODUCER-DONE`, keeping the count written in `progress`.
    private static func producer(writing total: Int) -> String {
        #"""
        /usr/bin/perl -e '
            my $chunk = (("x" x 1023) . "\r\n") x 64;
            my $written = 0;
            while ($written < \#(total)) {
                my $n = syswrite(STDOUT, $chunk);
                next unless defined $n;
                $written += $n;
                open(my $f, ">", "progress.tmp") or die; print $f $written; close $f; rename("progress.tmp", "progress");
            }
            syswrite(STDOUT, "PRODUCER-DONE");
        '
        """#
    }

    private static func progress(in fixture: GhosttyTabFixture) -> Int {
        (try? String(contentsOf: fixture.folder.appendingPathComponent("progress"), encoding: .utf8)).flatMap { Int($0) } ?? 0
    }

    /// Blocks the main thread until the process has written nothing for half a second, and returns what it wrote.
    private static func bytesWrittenOnceTheProcessStops(in fixture: GhosttyTabFixture) -> Int {
        let deadline = Date(timeIntervalSinceNow: 20)
        var written = progress(in: fixture)
        var unchangedSince = Date()
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            let now = progress(in: fixture)
            if now != written {
                written = now
                unchangedSince = Date()
            } else if written > 0, Date().timeIntervalSince(unchangedSince) > 0.5 {
                break
            }
        }
        return written
    }
}
