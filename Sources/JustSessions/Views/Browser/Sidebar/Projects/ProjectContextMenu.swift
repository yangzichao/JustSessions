import SwiftUI

/// Right-click menu for a project row in the sidebar.
struct ProjectContextMenu: View {
    @ObservedObject var store: ConversationStore
    let project: ProjectConversationGroup
    let onNewSession: (ConversationProvider) -> Void
    let onRename: () -> Void
    let onDeleteSessions: () -> Void
    let onRemoveProjectAndDeleteSessions: () -> Void

    var body: some View {
        let deletionPlan = store.deletionPlan(for: project.id)

        ProjectNewSessionMenu(
            project: project,
            providers: store.newSessionProviders(on: project.host),
            showsTitle: true,
            onStart: onNewSession
        )
        Button("New terminal", systemImage: "apple.terminal") {
            store.openPlainTerminal(in: project.location)
        }
        .disabled(!project.canStartNewSession)
        if project.host == .thisMac {
            Button("Open project in Finder", systemImage: "folder") {
                SessionLocationActions.openProjectFolder(project.location.path)
            }
            .disabled(!project.location.folderExistsOnThisMac)
            ProjectOpenInEditorMenu(editorStore: .shared, project: project, onError: store.showError)
        }
        Button("Copy project path", systemImage: "doc.on.doc") {
            SessionLocationActions.copyProjectPath(project.location.copyablePath)
        }
        Button("Rename project…", systemImage: "pencil", action: onRename)
        Button(project.isPinned ? "Unpin project" : "Pin project", systemImage: project.isPinned ? "pin.slash" : "pin") {
            store.setPinned(!project.isPinned, projectPath: project.projectPath)
        }
        Divider()
        Button("Remove from sidebar", systemImage: "sidebar.left") {
            store.removeProjectFromSidebar(project.id)
        }
        Divider()
        Button(
            "Delete all deletable sessions (\(deletionPlan.deletableConversations.count))…",
            systemImage: "trash",
            role: .destructive,
            action: onDeleteSessions
        )
        .disabled(!canDeleteSessions(deletionPlan))
        Button(
            "Remove project and delete all sessions (\(deletionPlan.deletableConversations.count))…",
            systemImage: "trash",
            role: .destructive,
            action: onRemoveProjectAndDeleteSessions
        )
        .disabled(!canDeleteSessions(deletionPlan))
    }

    private func canDeleteSessions(_ deletionPlan: SessionDeletionPlan) -> Bool {
        deletionPlan.hasDeletableConversations && store.canStartDeletion(of: deletionPlan.deletableConversations)
    }
}
