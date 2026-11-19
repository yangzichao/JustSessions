import AppKit
import Darwin
import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TerminalWindowVisibilityMeasurements {
    enum WindowState: String, CaseIterable {
        case inSight = "window in sight"
        case covered = "window covered by another window"
        case minimized = "window minimized"
        case hiddenTab = "bound: tab coalesced as hidden, window in sight"
    }

    @Test func selectedTabInWindowsInSightCoveredAndMinimized() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        for state in WindowState.allCases {
            var percentages: [Double] = []
            var observedStates: Set<String> = []
            for _ in 0..<5 {
                let run = try await measure(state)
                percentages.append(run.cpuPercentage)
                observedStates.insert(run.observedWindowState)
            }
            let median = String(format: "%.2f", percentages.sorted()[percentages.count / 2])
            let runs = percentages.map { String(format: "%.2f", $0) }.joined(separator: ", ")
            print(
                "TerminalWindowPerf | \(state.rawValue) | CPU percent of one core median=\(median) | runs=\(runs) | observed: \(observedStates.sorted().joined(separator: "; "))"
            )
        }
    }

    private func measure(_ state: WindowState) async throws -> (cpuPercentage: Double, observedWindowState: String) {
        _ = NSApplication.shared
        let frame = NSRect(x: 200, y: 200, width: 1000, height: 650)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let terminal = SelectableTerminalView(frame: NSRect(origin: .zero, size: frame.size))
        let insetView = TerminalInsetView(terminalView: terminal)
        window.contentView = insetView
        insetView.isShown = state != .hiddenTab
        terminal.feed(text: "\u{1B}[?25l")
        window.orderFrontRegardless()
        var cover: NSWindow?
        defer {
            insetView.isShown = true
            cover?.close()
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.contentView = nil
            window.close()
        }
        try await Task.sleep(for: .milliseconds(300))
        switch state {
        case .inSight, .hiddenTab:
            break
        case .covered:
            let coveringWindow = NSWindow(
                contentRect: frame.insetBy(dx: -100, dy: -100), styleMask: [.borderless], backing: .buffered, defer: false
            )
            coveringWindow.isReleasedWhenClosed = false
            coveringWindow.isOpaque = true
            coveringWindow.backgroundColor = .black
            coveringWindow.level = .floating
            coveringWindow.orderFrontRegardless()
            cover = coveringWindow
        case .minimized:
            window.miniaturize(nil)
        }
        // Minimizing animates, and occlusion is reported after the window server recomposites.
        try await Task.sleep(for: .seconds(1))
        let observedWindowState = "miniaturized=\(window.isMiniaturized), occlusion visible=\(window.occlusionState.contains(.visible))"

        let cpuStart = processCPUSeconds()
        let start = ContinuousClock.now
        var frameNumber = 0
        while ContinuousClock.now - start < .seconds(3) {
            let rows = (0..<40).map { row in
                "\u{1B}[\(row + 1);1H\u{1B}[2K\u{1B}[3\(1 + (row + frameNumber) % 6)mRow \(row) · frame \(frameNumber) · "
                    + String(repeating: "▇", count: (row * 7 + frameNumber) % 60) + "\u{1B}[0m"
            }.joined()
            terminal.dataReceived(slice: Array(rows.utf8)[...])
            frameNumber += 1
            try await Task.sleep(for: .milliseconds(33))
        }
        terminal.setWorkspaceActive(true)
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return ((processCPUSeconds() - cpuStart) / seconds * 100, observedWindowState)
    }

    private func processCPUSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}
