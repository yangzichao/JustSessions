import Foundation

/// A project a session's **Move to** menu offers: another project on the session's host whose folder a session can
/// start in, in the sidebar's order.
struct SessionMoveDestination: Identifiable, Equatable {
    let projectPath: String
    let displayName: String
    /// The parent folders of a project whose name another listed project shares; see `ProjectParentLabels`.
    let parentLabel: String?
    let folderPath: String

    var id: String { projectPath }

    var menuTitle: String {
        parentLabel.map { "\(displayName) — \($0)" } ?? displayName
    }

    /// `projects` in the sidebar's order, every host's.
    static func destinations(
        for conversation: Conversation,
        among projects: [ProjectConversationGroup]
    ) -> [SessionMoveDestination] {
        let projectsOnHost = projects.filter { $0.host == conversation.host }
        let parentLabels = ProjectParentLabels(projectsOnOneHost: projectsOnHost)
        return
            projectsOnHost
            .filter { $0.projectPath != conversation.projectDirectoryKey && $0.canStartNewSession }
            .map { project in
                SessionMoveDestination(
                    projectPath: project.projectPath,
                    displayName: project.displayName,
                    parentLabel: parentLabels.label(for: project),
                    folderPath: project.location.path
                )
            }
    }
}
