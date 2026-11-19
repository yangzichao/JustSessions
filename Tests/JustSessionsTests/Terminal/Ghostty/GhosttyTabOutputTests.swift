import AppKit
import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct GhosttyTabOutputTests {
    @Test func aFastProcessBlocksWhileItsOutputWaitsUnparsed() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.setWorkspaceActive(false)
        let total = 16 << 20
        try await fixture.start(printing: Self.producer(writing: total))
        try await expectEventually { Self.hasStarted(in: fixture) }
        fixture.signal("write")

        let written = Self.bytesWrittenOnceTheProcessStops(in: fixture)

        let limit = GhosttyOutputBackpressure.defaultHighWaterByteCount
        #expect(written > 0)
        #expect(written < limit + (2 << 20), "The process wrote \(written) bytes")
        #expect(fixture.view.outputBackpressure.unparsedByteCount < limit + (256 << 10))
        fixture.view.setWorkspaceActive(true)
        try await expectEventually { fixture.screen.contains("PRODUCER-DONE") }
        #expect(Self.progress(in: fixture) >= total)
    }

    @Test func everyLineArrivesInOrderAcrossPauses() async throws {
        let fixture = try GhosttyTabFixture(outputHighWaterByteCount: 4 << 10, outputLowWaterByteCount: 1 << 10)
        defer { fixture.tearDown() }
        let count = 3000
        try await fixture.start(
            printing: """
                i=1; while [ $i -le \(count) ]; do printf '%d\\r\\n' $i; i=$((i+1)); done; printf 'NUMBERS-DONE'
                """)
        Self.blockMainThread(for: 0.5)

        try await expectEventually { fixture.screen.contains("NUMBERS-DONE") }

        let numbers = try #require(fixture.selectAllText())
            .split(whereSeparator: \.isNewline)
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        #expect(numbers == Array(1...count))
    }

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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
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

        try await expectEventually { tab.hasExited }
        #expect(screenWhenTheProcessEnded?.contains("LAST-OUTPUT") == true, "\(screenWhenTheProcessEnded ?? "nil")")
    }

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

    private static func blockMainThread(for seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private static func producer(writing total: Int) -> String {
        #"""
        /usr/bin/perl -e '
            open(my $started, ">", "started") or die; close $started;
            select(undef, undef, undef, 0.01) until -e "write";
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

    private static func hasStarted(in fixture: GhosttyTabFixture) -> Bool {
        FileManager.default.fileExists(atPath: fixture.folder.appendingPathComponent("started").path)
    }

    private static func progress(in fixture: GhosttyTabFixture) -> Int {
        (try? String(contentsOf: fixture.folder.appendingPathComponent("progress"), encoding: .utf8)).flatMap { Int($0) } ?? 0
    }

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
