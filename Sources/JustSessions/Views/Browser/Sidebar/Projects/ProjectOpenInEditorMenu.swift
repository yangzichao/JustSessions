import SwiftUI

/// "Open project in" submenu of a project's menus, listing the installed editors that can open its folder: every one
/// for a folder on this Mac, and the VS Code-family ones for a folder on an SSH host. Shows nothing when none can.
struct ProjectOpenInEditorMenu: View {
    @ObservedObject var editorStore: ExternalEditorStore
    let location: ProjectLocation
    let projectDisplayName: String
    let onError: @MainActor (String) -> Void

    var body: some View {
        let editors = editorStore.editors(opening: location.host)
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
