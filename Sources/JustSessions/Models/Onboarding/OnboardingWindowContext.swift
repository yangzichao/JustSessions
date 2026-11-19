struct OnboardingWindowContext: Equatable {
    var readSessionID: String?
    var canResumeReadSession = false
    var sessionReadAtReadingTip: String?
    var hasSelectedTab = false
    var selectedTabCanKeepRunning = false
    var isSelectedTabInSplit = false
    var openTabCount = 0
    var isSidebarShown = true
}
