import AppKit
import SwiftUI

/// Whether the view's window shows on screen: not minimized, hidden with the app, on another Space, or covered whole,
/// by `occlusionState` as `WorkspaceWindowRegistry.hasWindowOnScreen` tells. A map out of sight checks and reads nothing
/// (PERF-89). Reported on the next turn, never during an update.
struct WindowVisibilityReader: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void
    @Environment(\.ignoresWindowOcclusion) private var ignoresOcclusion

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onChange = onChange
        view.ignoresOcclusion = ignoresOcclusion
        return view
    }

    func updateNSView(_ view: ReportingView, context: Context) {
        view.onChange = onChange
        view.ignoresOcclusion = ignoresOcclusion
    }

    final class ReportingView: NSView {
        var onChange: (@MainActor (Bool) -> Void)?
        var ignoresOcclusion = false
        private var reported: Bool?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Selector observers go with the view, as WorkingSpinner's do.
            let center = NotificationCenter.default
            for name in [
                NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
            ] {
                center.removeObserver(self, name: name, object: nil)
                if let window { center.addObserver(self, selector: #selector(windowChanged), name: name, object: window) }
            }
            report()
        }

        @objc private func windowChanged(_ notification: Notification) {
            report()
        }

        private func report() {
            let isVisible = window.map { (ignoresOcclusion || $0.occlusionState.contains(.visible)) && !$0.isMiniaturized } ?? false
            guard isVisible != reported else { return }
            reported = isVisible
            Task { @MainActor [weak self] in self?.onChange?(isVisible) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

extension EnvironmentValues {
    /// For tests: macOS reports no occlusion to a test process (see `TerminalWindowVisibilityMeasurements`), so its
    /// windows would never count as on screen. With this, a window counts unless it is minimized.
    @Entry var ignoresWindowOcclusion = false
}
