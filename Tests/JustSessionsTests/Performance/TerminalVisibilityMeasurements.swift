import AppKit
import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Controlled replay through the actual SwiftTerm input path; no paid CLI sessions or user terminals are started.
/// JUSTSESSIONS_PERF=1 swift test -c release --filter TerminalVisibilityMeasurements
@MainActor
@Suite(.serialized)
struct TerminalVisibilityMeasurements {
    @Test(arguments: [5, 10])
    func streamingHiddenTerminals(terminalCount: Int) async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        for optimized in [false, true] {
            var percentages: [Double] = []
            for _ in 0..<3 {
                percentages.append(try await measure(terminalCount: terminalCount, optimized: optimized))
            }
            let mode = optimized ? "coalesced hidden output" : "original opacity-only behavior"
            print("TerminalPerf | N=\(terminalCount) | \(mode) | CPU percent of one core median=\(String(format: "%.2f", percentages.sorted()[1])) | runs=\(percentages)")
        }
    }

    private func measure(terminalCount: Int, optimized: Bool) async throws -> Double {
        _ = NSApplication.shared
        let frame = NSRect(x: 0, y: 0, width: 1000, height: 650)
        let container = NSView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = container
        let views = (0..<terminalCount).map { index in
            let view = SelectableTerminalView(frame: frame)
            container.addSubview(view)
            view.alphaValue = index == 0 ? 1 : 0
            if optimized { view.setWorkspaceActive(index == 0) }
            view.feed(text: "\u{1B}[?25l")
            return view
        }
        window.orderFrontRegardless()
        defer {
            for view in views { view.setWorkspaceActive(true); view.removeFromSuperview() }
            window.contentView = nil
            window.close()
        }
        try await Task.sleep(for: .milliseconds(300))
        let heartbeat = MainThreadPerfHeartbeat()
        heartbeat.start()
        let cpuStart = processCPUSeconds()
        let start = ContinuousClock.now
        var frameNumber = 0
        while ContinuousClock.now - start < .seconds(3) {
            let lines = (0..<8).map { row in
                "\u{1B}[\(row + 1);1H\u{1B}[2K\u{1B}[36mWorking \(frameNumber % 4) — task \(row): waiting for generated output…\u{1B}[0m"
            }.joined()
            let bytes = Array(lines.utf8)
            for view in views { view.dataReceived(slice: bytes[...]) }
            frameNumber += 1
            try await Task.sleep(for: .milliseconds(33))
        }
        // Include the final flush instead of leaving its CPU outside the measurement.
        for view in views { view.setWorkspaceActive(true) }
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let percentage = (processCPUSeconds() - cpuStart) / seconds * 100
        heartbeat.stop()
        print("TerminalPerf | N=\(terminalCount) optimized=\(optimized) | frames=\(frameNumber) | longest main-thread gap=\(perfMilliseconds(heartbeat.longestGap))")
        return percentage
    }

    private func processCPUSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}
