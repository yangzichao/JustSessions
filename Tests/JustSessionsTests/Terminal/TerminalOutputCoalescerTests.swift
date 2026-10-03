import AppKit
import Testing
@testable import JustSessions

@MainActor
struct TerminalOutputCoalescerTests {
    @Test func backgroundChunksStayOrderedAndActivationFlushesImmediately() {
        let coalescer = TerminalOutputCoalescer()
        var received: [UInt8] = []
        var deliveries = 0
        coalescer.consume = { received += $0; deliveries += 1 }
        coalescer.isActive = false
        let bytes = Array("\u{1B}[31m你好 🐈\u{1B}[0m".utf8)
        for byte in bytes { coalescer.receive([byte][...]) }
        #expect(received.isEmpty)
        coalescer.isActive = true
        #expect(received == bytes)
        #expect(deliveries == 1)
        coalescer.receive([42][...])
        #expect(deliveries == 2)
        #expect(received == bytes + [42])
    }

    @Test func largeBackgroundBurstsStayBoundedAndLossless() {
        let coalescer = TerminalOutputCoalescer()
        coalescer.isActive = false
        var received: [UInt8] = []
        coalescer.consume = { received += $0 }
        let prefix = [UInt8](repeating: 1, count: 40_000)
        let large = [UInt8](repeating: 2, count: 100_000)
        coalescer.receive(prefix[...])
        coalescer.receive(large[...])
        #expect(received == prefix + large)
    }

    @Test func hiddenOutputIsEventuallyDeliveredWithoutActivation() async throws {
        let coalescer = TerminalOutputCoalescer()
        var received: [UInt8] = []
        coalescer.consume = { received += $0 }
        coalescer.isActive = false
        coalescer.receive([1, 2, 3][...])
        try await Task.sleep(for: .milliseconds(250))
        #expect(received == [1, 2, 3])
    }

    @Test func nativeTerminalHasCompleteUnicodeAndANSIStateWhenShown() {
        let view = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.setWorkspaceActive(false)
        for byte in "\u{1B}[31m你好 hidden output\u{1B}[0m".utf8 { view.dataReceived(slice: [byte][...]) }
        #expect(view.isHidden)
        view.setWorkspaceActive(true)
        view.selectAll()
        #expect(!view.isHidden)
        #expect(view.getSelection()?.contains("你好 hidden output") == true)
    }

    @Test func resizingAndProcessExitFlushPendingNativeOutput() {
        let view = SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.setWorkspaceActive(false)
        view.dataReceived(slice: Array("before resize\r\n".utf8)[...])
        view.setFrameSize(NSSize(width: 700, height: 450))
        view.selectAll()
        #expect(view.getSelection()?.contains("before resize") == true)
        view.selectNone()
        view.dataReceived(slice: Array("before exit".utf8)[...])
        view.processTerminated(view.process, exitCode: 0)
        view.selectAll()
        #expect(view.getSelection()?.contains("before exit") == true)
    }
}
