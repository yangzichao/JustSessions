import GhosttyTerminal

@MainActor
final class GridMetricsRecorder: TerminalSurfaceGridResizeDelegate {
    private(set) var metrics: TerminalGridMetrics?

    func terminalDidResize(_ size: TerminalGridMetrics) {
        metrics = size
    }
}
