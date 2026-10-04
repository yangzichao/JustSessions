import Testing
@testable import JustSessions

struct OnboardingTipDueTests {
    private let everyTipButTheTour = Set(OnboardingTip.allCases).subtracting([.tour])

    private func dueStops(
        in context: OnboardingWindowContext,
        among tipsToShow: Set<OnboardingTip>
    ) -> [OnboardingTourStop] {
        OnboardingTip.due(in: context, among: tipsToShow).flatMap(\.stops)
    }

    @Test func noTipIsDueBeforeTheTourHasShown() {
        let context = OnboardingWindowContext(readSessionID: "claude:1", canResumeReadSession: true)
        #expect(OnboardingTip.due(in: context, among: Set(OnboardingTip.allCases)).isEmpty)
    }

    @Test func readingASessionPointsAtResumeThenFind() {
        let context = OnboardingWindowContext(readSessionID: "claude:1", canResumeReadSession: true)
        let dueTips = OnboardingTip.due(in: context, among: everyTipButTheTour)
        #expect(dueTips.map(\.tip) == [.readingSession])
        #expect(dueTips.flatMap(\.stops) == [.resume, .findInConversation])
    }

    @Test func readingTipWaitsForASessionThatCanResume() {
        let context = OnboardingWindowContext(readSessionID: "claude:1", canResumeReadSession: false)
        #expect(dueStops(in: context, among: everyTipButTheTour).isEmpty)
    }

    @Test func sessionMenuAndSearchWaitForAnotherSessionAfterTheReadingTip() {
        let tipsToShow = everyTipButTheTour.subtracting([.readingSession])
        let sameSession = OnboardingWindowContext(readSessionID: "claude:1", canResumeReadSession: true, sessionReadAtReadingTip: "claude:1")
        #expect(dueStops(in: sameSession, among: tipsToShow).isEmpty)

        var anotherSession = sameSession
        anotherSession.readSessionID = "codex:2"
        #expect(dueStops(in: anotherSession, among: tipsToShow) == [.sessionMenu, .searchSessions])

        // Before the reading tip, another session gets the reading tip instead.
        #expect(dueStops(in: anotherSession, among: everyTipButTheTour) == [.resume, .findInConversation])
    }

    @Test func sessionMenuAndSearchWaitForTheSidebar() {
        let tipsToShow = everyTipButTheTour.subtracting([.readingSession])
        let context = OnboardingWindowContext(readSessionID: "claude:1", isSidebarShown: false)
        #expect(dueStops(in: context, among: tipsToShow).isEmpty)
    }

    @Test func firstTabPointsAtItsGroupTheSidebarToggleAndKeepRunning() {
        let context = OnboardingWindowContext(hasSelectedTab: true, selectedTabCanKeepRunning: true, openTabCount: 1)
        let dueTips = OnboardingTip.due(in: context, among: everyTipButTheTour)
        #expect(dueTips.map(\.tip) == [.terminalTab, .keepRunning])
        #expect(dueTips.flatMap(\.stops) == [.tabGroup, .hideSidebar, .keepRunning])
    }

    @Test func tabTipLeavesOutTheSidebarToggleWhileTheSidebarIsHidden() {
        let context = OnboardingWindowContext(hasSelectedTab: true, openTabCount: 1, isSidebarShown: false)
        #expect(dueStops(in: context, among: everyTipButTheTour) == [.tabGroup])
    }

    @Test func keepRunningWaitsForATabThatCanKeepRunning() {
        let plainTerminal = OnboardingWindowContext(hasSelectedTab: true, selectedTabCanKeepRunning: false, openTabCount: 1)
        #expect(dueStops(in: plainTerminal, among: [.keepRunning]).isEmpty)
    }

    @Test func secondTabPointsAtOpenTabs() {
        let tipsToShow = everyTipButTheTour.subtracting([.terminalTab, .keepRunning])
        let oneTab = OnboardingWindowContext(hasSelectedTab: true, openTabCount: 1)
        #expect(dueStops(in: oneTab, among: tipsToShow).isEmpty)

        let twoTabs = OnboardingWindowContext(hasSelectedTab: true, openTabCount: 2)
        #expect(dueStops(in: twoTabs, among: tipsToShow) == [.openTabs])
    }

    @Test func shownTipsAreNotDueAgain() {
        let context = OnboardingWindowContext(hasSelectedTab: true, selectedTabCanKeepRunning: true, openTabCount: 2)
        #expect(dueStops(in: context, among: [.readingSession, .browsingSessions]).isEmpty)
    }
}
