import SwiftUI

/// "Open project in" submenu of a project's menus, listing the editors installed on this Mac; for a project on an SSH
/// host, those that open it over SSH. Shows nothing when no such editor is installed.
struct ProjectOpenInEditorMenu: View {
    @ObservedObject var editorStore: ExternalEditorStore
    let location: ProjectLocation
    let projectDisplayName: String
    let onError: @MainActor (String) -> Void

    var body: some View {
        let editors = editorStore.editors(for: location)
        if !editors.isEmpty {
            Menu {
                ForEach(editors) { editor in
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
            // A folder on an SSH host is not checked; the editor reports it when it is gone.
            .disabled(location.host == .thisMac && !location.folderExistsOnThisMac)
        }
    }

    private func open(in editor: InstalledExternalEditor) {
        let location = location
        let projectName = projectDisplayName
        Task {
            do {
                try await editorStore.open(location, in: editor)
            } catch {
                onError("Could not open \(projectName) in \(editor.name): \(error.localizedDescription)")
            }
        }
    }
}
