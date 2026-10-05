/// Onboarding that shows on its own, once each, on an install that was fresh: the tour at the first launch, then a
/// few stops the first time each part of the window comes into use, so nothing is taught before it is needed.
enum OnboardingTip: String, CaseIterable, Sendable {
    /// The tour of the sidebar, at the first launch.
    case tour
    /// The first session read: Resume, then finding text in its conversation.
    case readingSession
    /// Another session read after that: the session's right-click menu, then search.
    case browsingSessions
    /// The first tab: its group label, which collapses the project's tabs, then the sidebar toggle.
    case terminalTab
    /// Keep running, on the first tab whose CLI can keep running.
    case keepRunning
    /// A second tab: Open tabs, which lists them all.
    case openTabs
    /// A second tab, while the selected one is in no split: split view, which shows two tabs side by side.
    case splitView
}
