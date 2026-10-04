/// Onboarding that shows on its own, once, after a fresh install.
enum OnboardingTip: String, CaseIterable, Sendable {
    /// The tour of the sidebar, at the first launch.
    case tour
    /// Keep running, pointed out on the first tab whose CLI can keep running.
    case keepRunning
}
