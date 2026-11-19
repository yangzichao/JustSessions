extension OnboardingTip {
    static func due(
        in context: OnboardingWindowContext,
        among tipsToShow: Set<OnboardingTip>
    ) -> [(tip: OnboardingTip, stops: [OnboardingTourStop])] {
        guard !tipsToShow.contains(.tour) else { return [] }
        return allCases.filter(tipsToShow.contains).compactMap { tip in
            let stops = tip.stops(in: context, among: tipsToShow)
            return stops.isEmpty ? nil : (tip, stops)
        }
    }

    private func stops(in context: OnboardingWindowContext, among tipsToShow: Set<OnboardingTip>) -> [OnboardingTourStop] {
        let stops: [OnboardingTourStop]
        switch self {
        case .tour:
            return []
        case .readingSession:
            guard context.canResumeReadSession else { return [] }
            stops = [.resume, .findInConversation]
        case .browsingSessions:
            guard !tipsToShow.contains(.readingSession), context.readSessionID != context.sessionReadAtReadingTip
            else { return [] }
            stops = [.sessionMenu, .searchSessions]
        case .terminalTab:
            guard context.hasSelectedTab else { return [] }
            stops = [.tabGroup, .hideSidebar]
        case .keepRunning:
            stops = [.keepRunning]
        case .openTabs:
            stops = [.openTabs]
        case .splitView:
            stops = [.splitView]
        }
        return stops.filter { $0.canShow(in: context) }
    }
}
