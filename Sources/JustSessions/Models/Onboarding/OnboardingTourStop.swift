enum OnboardingTourStop: CaseIterable, Sendable {
    case noSessionsYet
    case projects
    case sessions
    case newSession
    case sshHosts
    case keepRunning
    case resume
    case findInConversation
    case sessionMenu
    case searchSessions
    case tabGroup
    case hideSidebar
    case openTabs
    case splitView

    static func tour(listsProjectWithSessions: Bool, selectedTabCanKeepRunning: Bool) -> [OnboardingTourStop] {
        var stops: [OnboardingTourStop] = listsProjectWithSessions ? [.projects, .sessions] : [.noSessionsYet]
        stops += [.newSession, .sshHosts]
        if selectedTabCanKeepRunning { stops.append(.keepRunning) }
        return stops
    }

    var isTourStopInProjectList: Bool {
        switch self {
        case .noSessionsYet, .projects, .sessions: true
        case .newSession, .sshHosts, .keepRunning, .resume, .findInConversation, .sessionMenu, .searchSessions, .tabGroup,
            .hideSidebar, .openTabs, .splitView:
            false
        }
    }

    func canShow(in context: OnboardingWindowContext) -> Bool {
        switch self {
        case .noSessionsYet, .projects, .sessions, .newSession, .sshHosts: true
        case .keepRunning: context.selectedTabCanKeepRunning
        case .resume, .findInConversation: context.readSessionID != nil
        case .sessionMenu: context.readSessionID != nil && context.isSidebarShown
        case .searchSessions: context.isSidebarShown
        case .tabGroup: context.hasSelectedTab
        case .hideSidebar: context.hasSelectedTab && context.isSidebarShown
        case .openTabs: context.openTabCount > 1 && context.isSidebarShown
        case .splitView: context.hasSelectedTab && context.openTabCount > 1 && !context.isSelectedTabInSplit
        }
    }
}
