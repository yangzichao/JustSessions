import Foundation

struct SessionMoveDestination: Identifiable, Equatable {
    let projectPath: String
    let displayName: String
    let parentLabel: String?
    let folderPath: String

    var id: String { projectPath }

    var menuTitle: String {
        parentLabel.map { "\(displayName) — \($0)" } ?? displayName
    }

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
