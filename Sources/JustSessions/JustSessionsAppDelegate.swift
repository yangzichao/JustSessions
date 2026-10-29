import AppKit

/// AppKit launch events and the Dock menu, which SwiftUI's `App` has no hook for.
final class JustSessionsAppDelegate: NSObject, NSApplicationDelegate {
    /// `NSApp` does not exist yet while `JustSessionsApp` is created. Here it does, and no window is open, so the
    /// first window already opens in the saved appearance. Clicks on notifications need their handler this early too.
    /// Onboarding reads whether this is a fresh install before anything this launch saves a setting, and the random tip
    /// whether onboarding's tour is due before it starts.
    ///
    /// The app's own tab bar holds its tabs, so a window has no macOS tab bar: shown with View → Show Tab Bar, it lay
    /// under the app's bar and the terminal's first row, invisible, and took every click there, such as on the × of
    /// Claude Code's diff panel. Turning tabbing off before the first window opens hides a bar shown before and removes
    /// the menu items.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        _ = OnboardingTipsStore.shared
        _ = RandomTipsStore.shared
        AppAppearanceStore.shared.applyToApplication()
        SessionNotificationCenter.shared.startHandlingClicks()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        GhosttyResourcesLaunchCheck.runIfAsked()
        LaunchCrashReportOffer.offerIfTheLastRunCrashed()
        ZoomInEqualsKey.startForwarding()
        SSHHostReachabilityResets.shared.start()
        HostAutoRefresher.shared.start()
        RemoteTabReconnector.shared.start()
        SSHPortForwards.shared.start()
        DispatchQueue.global(qos: .utility).async {
            SSHLoginConnections.closeLoginsOfEndedApps()
            SSHPortForwardConnection.closeConnectionsOfEndedApps()
        }
    }

    /// Port forwards and logins made with Connect… end with the app; nothing it typed for them is kept.
    func applicationWillTerminate(_ notification: Notification) {
        SSHPortForwards.shared.endAll()
        SSHLoginConnections.shared.disconnectAll()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        WorkspaceDockMenu.shared.makeMenu()
    }
}
