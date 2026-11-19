import SwiftUI

/// What ⌘-clicking a link to a file on this Mac does; see `FileLinkClickChoice`. The editors are the installed ones
/// "Open in" lists. A chosen editor that has since been removed shows as the default app, which is where such a file
/// then opens.
struct FileLinkClickChoicePicker: View {
    @ObservedObject var fileLinkClickSettingsStore: FileLinkClickSettingsStore
    @ObservedObject var editorStore: ExternalEditorStore

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Picker(
                "When you ⌘-click a file",
                selection: Binding(
                    get: { shownChoice },
                    set: { fileLinkClickSettingsStore.setChoice($0) }
                )
            ) {
                Text("Open in its default app").tag(FileLinkClickChoice.defaultApp)
                Text("Ask each time").tag(FileLinkClickChoice.askEachTime)
                if !editors.isEmpty {
                    Divider()
                    ForEach(editors) { editor in
                        Text("Open in \(editor.name)").tag(FileLinkClickChoice.editor(name: editor.name))
                    }
                }
            }
            .fixedSize()
            .accessibilityIdentifier("settings.fileLinkClickChoice")
            HelpPopoverButton(
                title: "File links",
                explanation:
                    "A web address always opens in your browser, and a folder in the Finder. An editor opens text files, such as code and Markdown, at the printed line when it's VS Code or an editor built on it; images, PDFs, and other files open in their default app. Right-click a link for every choice."
            )
            .accessibilityIdentifier("settings.help.fileLinks")
        }
    }

    private var editors: [InstalledExternalEditor] {
        editorStore.editors(opening: .thisMac)
    }

    private var shownChoice: FileLinkClickChoice {
        let choice = fileLinkClickSettingsStore.choice
        guard case .editor(let name) = choice else { return choice }
        return editors.contains { $0.name == name } ? choice : .defaultApp
    }
}
