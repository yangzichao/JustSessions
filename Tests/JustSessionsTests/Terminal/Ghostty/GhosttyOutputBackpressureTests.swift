import AppKit
import Foundation
import GhosttyTerminal
import Testing
@testable import JustSessions

@MainActor
struct GhosttyOutputBackpressureTests {
    @Test func readingWaitsWhileOutputOnItsWayToGhosttyIsOverTheLimit() async throws {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let backpressure = GhosttyOutputBackpressure(session: session, highWaterByteCount: 64 << 10, lowWaterByteCount: 16 << 10)
        defer { backpressure.stop() }
        backpressure.outputHandedToMainThread(byteCount: 63 << 10)
        let firstRead = Waiter(backpressure)
        try await expectEventually { firstRead.hasReturned }

        backpressure.outputHandedToMainThread(byteCount: 1 << 10)
        let read = Waiter(backpressure)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!read.hasReturned)

        backpressure.outputPassedToGhostty(byteCount: 40 << 10)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!read.hasReturned, "Above the low-water mark")

        backpressure.outputPassedToGhostty(byteCount: 8 << 10)
        try await expectEventually { read.hasReturned }
        #expect(backpressure.unparsedByteCount == 16 << 10)
    }

    /// Output Ghostty has not parsed counts too: here it waits for a surface, which it gets once in a window.
    @Test func readingWaitsWhileGhosttyHasNotParsedTheOutput() async throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let backpressure = GhosttyOutputBackpressure(session: session, highWaterByteCount: 64 << 10, lowWaterByteCount: 16 << 10)
        defer { backpressure.stop() }
        session.receive(Data(repeating: UInt8(ascii: "x"), count: 100 << 10))
        #expect(backpressure.unparsedByteCount == 100 << 10)

        let read = Waiter(backpressure)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!read.hasReturned)

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

        try await expectEventually { read.hasReturned }
    }

    @Test func stoppingEndsTheWait() async throws {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let backpressure = GhosttyOutputBackpressure(session: session, highWaterByteCount: 64 << 10, lowWaterByteCount: 16 << 10)
        defer { backpressure.stop() }
        backpressure.outputHandedToMainThread(byteCount: 64 << 10)
        let read = Waiter(backpressure)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!read.hasReturned)

        backpressure.stop()

        try await expectEventually { read.hasReturned }
    }
}

/// Calls `waitForRoom()` on a thread of its own, as the tab's process queue does. Each test stops its backpressure
/// when it ends, so a wait a failed expectation leaves behind ends too.
private final class Waiter: @unchecked Sendable {
    private let lock = NSLock()
    private var returned = false

    init(_ backpressure: GhosttyOutputBackpressure) {
        DispatchQueue.global().async { [self] in
            backpressure.waitForRoom()
            lock.withLock { returned = true }
        }
    }

    var hasReturned: Bool { lock.withLock { returned } }
}
