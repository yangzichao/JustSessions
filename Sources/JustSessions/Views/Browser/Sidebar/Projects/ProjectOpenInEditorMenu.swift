import SwiftUI

/// "Open project in" submenu of a project's menus, listing the editors installed on this Mac.
/// Shows nothing when no known editor is installed.
struct ProjectOpenInEditorMenu: View {
    @ObservedObject var editorStore: ExternalEditorStore
    let location: ProjectLocation
    let projectDisplayName: String
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
            .disabled(!location.folderExistsOnThisMac)
        }
    }

    private func open(in editor: InstalledExternalEditor) {
        let folderPath = location.path
        let projectName = projectDisplayName
        Task {
            do {
                try await editorStore.open(folderPath: folderPath, in: editor)
            } catch {
                onError("Could not open \(projectName) in \(editor.name): \(error.localizedDescription)")
            }
        }
    }
}
