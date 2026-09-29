import AppKit

/// AppKit launch events that SwiftUI's `App` has no hook for.
final class JustSessionsAppDelegate: NSObject, NSApplicationDelegate {
    /// `NSApp` does not exist yet while `JustSessionsApp` is created. Here it does, and no window is open, so the
    /// first window already opens in the saved appearance.
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppAppearanceStore.shared.applyToApplication()
    }
}
