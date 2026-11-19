import SwiftUI

struct ProjectFolderMenuItems: View {
    let store: ConversationStore
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
        }
        ProjectOpenInEditorMenu(
            editorStore: .shared,
            location: location,
            projectDisplayName: projectDisplayName,
            onError: store.showError
        )
        Button("Copy project path", systemImage: "doc.on.doc") {
            SessionLocationActions.copyProjectPath(location.copyablePath)
        }
    }
}
