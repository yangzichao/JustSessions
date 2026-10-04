/// A control the onboarding tour points at, in the order the tour visits them.
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

    /// The window's tour: its sessions when it lists some, or else where they will appear; then starting a session and
    /// adding an SSH host; then Keep running, when the selected tab can.
    static func tour(listsProjectWithSessions: Bool, selectedTabCanKeepRunning: Bool) -> [OnboardingTourStop] {
        var stops: [OnboardingTourStop] = listsProjectWithSessions ? [.projects, .sessions] : [.noSessionsYet]
        stops += [.newSession, .sshHosts]
        if selectedTabCanKeepRunning { stops.append(.keepRunning) }
        return stops
    }

    /// In the sidebar's project list, which has to show for the stop to.
    var isInProjectList: Bool {
        switch self {
        case .noSessionsYet, .projects, .sessions: true
        case .newSession, .sshHosts, .keepRunning: false
        }
    }
}
