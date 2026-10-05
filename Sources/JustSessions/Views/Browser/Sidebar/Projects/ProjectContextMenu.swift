import SwiftUI

/// A project row's menu, from a right-click or its ⋯ button.
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
        Button("Archive project", systemImage: "archivebox") {
            store.removeProjectFromSidebar(project.id)
        }
        Divider()
        Button(
            "Delete all deletable sessions (\(deletionPlan.deletableConversations.count))…",
            systemImage: "trash",
            role: .destructive,
            action: onDeleteSessions
        )
        .disabled(!deletionPlan.hasDeletableConversations)
        Button(
            "Archive project and delete all sessions (\(deletionPlan.deletableConversations.count))…",
            systemImage: "trash",
            role: .destructive,
            action: onRemoveProjectAndDeleteSessions
        )
        .disabled(!deletionPlan.hasDeletableConversations)
    }
}
