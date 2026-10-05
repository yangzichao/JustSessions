import SwiftUI

/// What a project's menus offer for its folder: a new session or terminal there, opening it, or copying its path. A
/// project row's menu adds what arranges the project in the sidebar; an open tab group's menu has only these.
struct ProjectFolderMenuItems: View {
    @ObservedObject var store: ConversationStore
    let location: ProjectLocation
    let projectDisplayName: String
    let onNewSession: (ConversationProvider) -> Void

    var body: some View {
        ProjectNewSessionMenu(
            location: location,
            projectDisplayName: projectDisplayName,
            providers: store.newSessionProviders(on: location.host),
            showsTitle: true,
            onStart: onNewSession
        )
        Button("New terminal", systemImage: "apple.terminal") {
            store.openPlainTerminal(in: location)
        }
        .disabled(!location.canStartSessions)
        if location.host == .thisMac {
            Button("Open project in Finder", systemImage: "folder") {
                SessionLocationActions.openProjectFolder(location.path)
            }
            .disabled(!location.folderExistsOnThisMac)
            ProjectOpenInEditorMenu(
                editorStore: .shared,
                location: location,
                projectDisplayName: projectDisplayName,
                onError: store.showError
            )
        }
        Button("Copy project path", systemImage: "doc.on.doc") {
            SessionLocationActions.copyProjectPath(location.copyablePath)
        }
    }
}
