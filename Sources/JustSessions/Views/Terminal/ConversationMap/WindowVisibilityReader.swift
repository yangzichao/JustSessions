import AppKit
import SwiftUI

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
            let center = NotificationCenter.default
            for name in [
                NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
            ] {
                center.removeObserver(self, name: name, object: nil)
                if let window { center.addObserver(self, selector: #selector(windowChanged), name: name, object: window) }
            }
            report()
        }

        @objc private func windowChanged(_: Notification) {
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
