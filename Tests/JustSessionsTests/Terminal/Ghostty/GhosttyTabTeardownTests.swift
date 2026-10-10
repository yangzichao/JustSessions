import AppKit
import Darwin
import Foundation
import GhosttyTerminal
import ObjectiveC
import Testing
@testable import JustSessions

/// A Ghostty tab that goes away while the reading of its process's output waits for Ghostty to catch up.
@MainActor
@Suite(.serialized)
struct GhosttyTabTeardownTests {
    /// Small, so a fast process reaches them at once.
    private static let highWaterByteCount = 64 << 10
    private static let lowWaterByteCount = 16 << 10

    /// While the main thread is busy, the paused read waits for it, so closing the tab must not wait for that read.
    @Test func terminatingAPausedTabReturnsAndEndsItsProcess() async throws {
        let fixture = try GhosttyTabFixture(
            outputHighWaterByteCount: Self.highWaterByteCount,
            outputLowWaterByteCount: Self.lowWaterByteCount
        )
        defer { fixture.tearDown() }
        fixture.view.startProcess(
            executable: "/bin/sh",
            args: ["-c", Self.endlessProducer],
            environment: Self.environment(in: fixture.folder),
            execName: nil,
            currentDirectory: fixture.folder.path
        )
        try #require(Self.blockMainThreadUntilReadingPauses(fixture.view.outputBackpressure))
        let processID = fixture.view.processID
        // Without it a broken `terminate()` would wait forever, and the test with it.
        let rescue = PausedReadRescue(fixture.view.outputBackpressure, after: .seconds(10))

        let elapsed = ContinuousClock().measure { fixture.view.terminate() }

        #expect(!rescue.finish(), "terminate() waited for the paused read until the test ended the wait")
        #expect(elapsed < .seconds(3), "terminate() took \(elapsed)")
        #expect(Self.blockMainThreadUntilExited(processID), "The process kept running")
    }

    /// As when a tab whose process ended closes while a job the process left behind still writes: nothing calls
    /// `terminate()`, and the tab's view is let go while a read waits for room. Here the read waits for a Ghostty
    /// that has not parsed the output, as Ghostty can't before the view is in a window. The view must be freed at
    /// once, on the main thread, where its Ghostty surface is freed, and the waiting read must stop waiting and hand
    /// on what it read. AppKit on macOS 26 already moves an NSView's last release to the main thread, so there the
    /// view being freed at once, not held by the waiting read, is what shows the read never holds it.
    @Test func aPausedTabsViewIsFreedOnTheMainThreadAndStopsReading() async throws {
        let settings = try IsolatedUserDefaults()
        let folder = try makeTemporaryDirectory()
        defer {
            settings.removeSuite()
            try? FileManager.default.removeItem(at: folder)
        }
        let freeing = FreeingRecord()
        var view: GhosttyTabTerminalView? = GhosttyTabTerminalView(
            frame: NSRect(x: 0, y: 0, width: 640, height: 400),
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
            themeStore: AppThemeStore(userDefaults: settings.userDefaults),
            outputHighWaterByteCount: Self.highWaterByteCount,
            outputLowWaterByteCount: Self.lowWaterByteCount
        )
        freeing.watch(try #require(view))
        view?.startProcess(
            executable: "/bin/sh",
            args: ["-c", Self.endlessProducer],
            environment: Self.environment(in: folder),
            execName: nil,
            currentDirectory: folder.path
        )
        let processID = try #require(view?.processID)
        defer {
            kill(processID, SIGTERM)
            ClosedTabProcessReaper.reapOnceExited(processID)
        }
        let session = try #require(view?.inMemorySession)
        let backpressure = try #require(view?.outputBackpressure)
        try #require(await Self.waitUntilReadingPauses(backpressure))
        let unparsedWhilePaused = backpressure.unparsedByteCount

        view = nil

        try await expectEventually { freeing.wasFreed }
        try await expectEventually { backpressure.unparsedByteCount > unparsedWhilePaused }
        // A view the paused read held on to would go once Ghostty parsed the output; this parses it.
        try await Self.parseOutput(of: session, settings: settings)
        try await expectEventually { freeing.wasFreed }
        #expect(freeing.wasFreedOnMainThread == true)
    }

    /// Writes 64 KiB at a time until a write fails or it is told to end. It then throws away the output the
    /// terminal has not read before it ends: closing a terminal waits for that output to be read, which never happens
    /// while another test's process holds the terminal open, as each process started on a pseudo-terminal holds
    /// those of the terminals started before it.
    private static let endlessProducer = #"""
        exec /usr/bin/perl -MPOSIX -e '
            sub finish { POSIX::tcflush(1, POSIX::TCOFLUSH); POSIX::_exit(0) }
            $SIG{TERM} = $SIG{HUP} = \&finish;
            my $chunk = (("x" x 1023) . "\r\n") x 64;
            while (1) { defined(syswrite(STDOUT, $chunk)) or finish() }
        '
        """#

    private static func environment(in folder: URL) -> [String] {
        ["HOME=\(folder.path)", "PATH=/usr/bin:/bin", "TERM=xterm-256color", "LANG=en_US.UTF-8"]
    }

    /// Blocks the main thread, so no output reaches Ghostty, until the output read stops growing at the high-water
    /// mark: the reading waits for room. Returns whether it did within 20 seconds.
    private static func blockMainThreadUntilReadingPauses(_ backpressure: GhosttyOutputBackpressure) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 20)
        var unparsed = backpressure.unparsedByteCount
        var unchangedSince = Date()
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
            let now = backpressure.unparsedByteCount
            if now != unparsed {
                unparsed = now
                unchangedSince = Date()
            } else if unparsed >= highWaterByteCount, Date().timeIntervalSince(unchangedSince) > 0.3 {
                return true
            }
        }
        return false
    }

    /// Waits, with the main thread free to pass output on, until the output read stops growing at the high-water
    /// mark: the reading waits for room. Returns whether it did within 20 seconds.
    private static func waitUntilReadingPauses(_ backpressure: GhosttyOutputBackpressure) async throws -> Bool {
        let deadline = ContinuousClock.now + .seconds(20)
        var unparsed = backpressure.unparsedByteCount
        var unchangedSince = ContinuousClock.now
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
            let now = backpressure.unparsedByteCount
            if now != unparsed {
                unparsed = now
                unchangedSince = .now
            } else if unparsed >= highWaterByteCount, ContinuousClock.now - unchangedSince > .milliseconds(300) {
                return true
            }
        }
        return false
    }

    /// Gives the session a Ghostty surface, in a window of its own, until it has parsed its output.
    private static func parseOutput(of session: InMemoryTerminalSession, settings: IsolatedUserDefaults) async throws {
        let view = AppTerminalView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        view.controller = GhosttyTerminalControllers.shared.controller(
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
            themeStore: AppThemeStore(userDefaults: settings.userDefaults)
        )
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer {
            window.contentView = nil
            window.close()
        }
        try await expectEventually { session.pendingOutputByteCount == 0 }
    }

    /// Returns whether the process ended within 10 seconds, and reaps it.
    private static func blockMainThreadUntilExited(_ processID: pid_t) -> Bool {
        guard processID > 0 else { return false }
        let deadline = Date(timeIntervalSinceNow: 10)
        while Date() < deadline {
            if waitpid(processID, nil, WNOHANG) == processID { return true }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return false
    }
}

/// Ends the wait of a paused read from another thread if the test's main thread is still busy after a while, so a
/// test of a deadlock fails rather than hangs.
private final class PausedReadRescue: @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private var hasRescued = false

    init(_ backpressure: GhosttyOutputBackpressure, after delay: DispatchTimeInterval) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            let rescues = lock.withLock {
                hasRescued = !isFinished
                return hasRescued
            }
            if rescues { backpressure.stop() }
        }
    }

    /// Returns whether the rescue had to end the wait.
    func finish() -> Bool {
        lock.withLock {
            isFinished = true
            return hasRescued
        }
    }
}

/// Records the thread an object is freed on, through an object attached to it, which is freed along with it.
private final class FreeingRecord: @unchecked Sendable {
    nonisolated(unsafe) private static var attachmentKey: UInt8 = 0
    private let lock = NSLock()
    private var freedOnMainThread: Bool?

    func watch(_ object: NSObject) {
        objc_setAssociatedObject(object, &Self.attachmentKey, Attachment(self), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    var wasFreed: Bool { lock.withLock { freedOnMainThread != nil } }
    var wasFreedOnMainThread: Bool? { lock.withLock { freedOnMainThread } }

    private func recordFreeing() {
        let isMainThread = Thread.isMainThread
        lock.withLock { freedOnMainThread = isMainThread }
    }

    private final class Attachment {
        private let record: FreeingRecord

        init(_ record: FreeingRecord) {
            self.record = record
        }

        deinit {
            record.recordFreeing()
        }
    }
}
