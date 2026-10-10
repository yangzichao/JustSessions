import AppKit

/// AppKit launch events and the Dock menu, which SwiftUI's `App` has no hook for.
final class JustSessionsAppDelegate: NSObject, NSApplicationDelegate {
    /// `NSApp` does not exist yet while `JustSessionsApp` is created. Here it does, and no window is open, so the
    /// first window already opens in the saved appearance. Clicks on notifications need their handler this early too.
    /// Onboarding reads whether this is a fresh install before anything this launch saves a setting.
    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = OnboardingTipsStore.shared
        AppAppearanceStore.shared.applyToApplication()
        SessionNotificationCenter.shared.startHandlingClicks()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchCrashReportOffer.offerIfTheLastRunCrashed()
        ZoomInEqualsKey.startForwarding()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        WorkspaceDockMenu.shared.makeMenu()
    }
}
