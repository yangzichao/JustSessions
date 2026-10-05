/// A control an onboarding tip points at: the tour's, in the order it visits them, then the ones a tip points at
/// the first time part of the window comes into use.
enum OnboardingTourStop: CaseIterable, Sendable {
    /// This Mac's note while it lists no sessions: where they will appear.
    case noSessionsYet
    /// The first listed project with sessions.
    case projects
    /// That project's first session, once the tour opens the project.
    case sessions
    /// The + at the top of the sidebar.
    case newSession
    /// Add SSH host… at the bottom of the sidebar.
    case sshHosts
    /// The selected tab, while its CLI can keep running after the tab closes.
    case keepRunning
    /// Resume above the conversation being read.
    case resume
    /// Find in the reading toolbar.
    case findInConversation
    /// The read session's row in the sidebar, for its right-click menu.
    case sessionMenu
    /// Search at the top of the sidebar.
    case searchSessions
    /// The label of the selected tab's group in the tab bar.
    case tabGroup
    /// The sidebar toggle in the title bar.
    case hideSidebar
    /// Open tabs at the top of the sidebar.
    case openTabs
    /// The selected tab, while it is in no split and another tab could open in one with it.
    case splitView

    /// The window's tour: its sessions when it lists some, or else where they will appear; then starting a session and
    /// adding an SSH host; then Keep running, when the selected tab can.
    static func tour(listsProjectWithSessions: Bool, selectedTabCanKeepRunning: Bool) -> [OnboardingTourStop] {
        var stops: [OnboardingTourStop] = listsProjectWithSessions ? [.projects, .sessions] : [.noSessionsYet]
        stops += [.newSession, .sshHosts]
        if selectedTabCanKeepRunning { stops.append(.keepRunning) }
        return stops
    }

    /// One of the tour's stops in the sidebar's project list, which brings the tour's project into sight for it.
    var isTourStopInProjectList: Bool {
        switch self {
        case .noSessionsYet, .projects, .sessions: true
        case .newSession, .sshHosts, .keepRunning, .resume, .findInConversation, .sessionMenu, .searchSessions, .tabGroup,
             .hideSidebar, .openTabs, .splitView: false
        }
    }

    /// Whether the control this stop points at is in use in `context`. A tip moves past a stop that isn't, as when
    /// Resume opens a tab over the conversation, or the sidebar its tip pointed at is hidden.
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
