/// What a workspace window shows, which decides the onboarding tips due in it and the stops that can still show.
struct OnboardingWindowContext: Equatable {
    /// The session whose conversation shows; nil while a tab, or nothing, shows instead.
    var readSessionID: String?
    var canResumeReadSession = false
    /// The session read when the reading tip showed in this window, so the next tip waits until another one is read.
    var sessionReadAtReadingTip: String?
    var hasSelectedTab = false
    var selectedTabCanKeepRunning = false
    var openTabCount = 0
    var isSidebarShown = true
}
