import SwiftUI

/// "Open project in" submenu of the project right-click menu, listing the editors installed on this Mac.
/// Shows nothing when no known editor is installed.
struct ProjectOpenInEditorMenu: View {
    @ObservedObject var editorStore: ExternalEditorStore
    let project: ProjectConversationGroup
    let onError: @MainActor (String) -> Void

    var body: some View {
        if !editorStore.installedEditors.isEmpty {
            Menu {
                ForEach(editorStore.installedEditors) { editor in
                    Button {
                        open(in: editor)
                    } label: {
                        Label {
                            Text(editor.name)
                        } icon: {
                            Image(nsImage: editor.icon)
                        }
                    }
                }
            } label: {
                Label("Open project in", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .disabled(!project.location.folderExistsOnThisMac)
        }
    }

    private func open(in editor: InstalledExternalEditor) {
        let folderPath = project.location.path
        let projectName = project.displayName
        Task {
            do {
                try await editorStore.open(folderPath: folderPath, in: editor)
            } catch {
                onError("Could not open \(projectName) in \(editor.name): \(error.localizedDescription)")
            }
        }
    }
}
