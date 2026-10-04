import AppKit
import SwiftUI

/// Settings save immediately, so leaving this sheet open must not block Quit or Sparkle's Install and Relaunch.
/// Apply this only to the settings sheet's native window; other sheets keep their normal termination protection.
struct SettingsSheetTerminationPolicy: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsSheetTerminationPolicyView {
        SettingsSheetTerminationPolicyView()
    }

    func updateNSView(_ view: SettingsSheetTerminationPolicyView, context: Context) {
        view.allowTermination()
    }

    static func dismantleNSView(_ view: SettingsSheetTerminationPolicyView, coordinator: ()) {
        view.restoreTerminationPolicy()
    }
}

final class SettingsSheetTerminationPolicyView: NSView {
    private weak var configuredWindow: NSWindow?
    private var previousPreventsTermination = true

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        allowTermination()
    }

    func allowTermination() {
        if configuredWindow !== window {
            restoreTerminationPolicy()
            configuredWindow = window
            previousPreventsTermination = window?.preventsApplicationTerminationWhenModal ?? true
        }
        window?.preventsApplicationTerminationWhenModal = false
    }

    func restoreTerminationPolicy() {
        configuredWindow?.preventsApplicationTerminationWhenModal = previousPreventsTermination
        configuredWindow = nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
