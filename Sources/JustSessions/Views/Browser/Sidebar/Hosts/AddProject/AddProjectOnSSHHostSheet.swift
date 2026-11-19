import SwiftUI

struct AddProjectOnSSHHostSheet: View {
    let store: ConversationStore
    let host: SessionHost
    let onAdded: (String) -> Void

    private enum FolderRequest {
        case lookingUp
        case creating
    }

    @Environment(\.dismiss) private var dismiss
    @State private var folder = ""
    @State private var runningFolderRequest: FolderRequest?
    @State private var missingFolder: String?
    @State private var errorMessage: String?

    private var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var offersToCreateMissingFolder: Bool {
        missingFolder != nil && missingFolder == trimmedFolder
    }

    var body: some View {
        ThemeSheetLayout(
            title: Text("Add project"),
            intro: Text("The folder is listed under \(host.displayName) in the sidebar, ready for new sessions."),
            width: ThemeSheetMetrics.compactWidth
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Project folder on \(host.displayName)")
                    .font(ThemeFont.fieldLabel)
                TextField("Path on the host, such as ~/code/app", text: $folder)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .accessibilityLabel("Project folder")
                    .onSubmit(addFolder)
                if offersToCreateMissingFolder {
                    Text("There is no folder \(trimmedFolder) on \(host.displayName). Create it to add the project.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } footer: {
            if let runningFolderRequest {
                ProgressView().controlSize(.small)
                Text(progressText(for: runningFolderRequest))
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(addButtonTitle, action: addFolder)
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedFolder.isEmpty || runningFolderRequest != nil)
        }
    }

    private var addButtonTitle: LocalizedStringKey {
        offersToCreateMissingFolder ? "Create folder and add" : "Add project"
    }

    private func progressText(for folderRequest: FolderRequest) -> LocalizedStringKey {
        switch folderRequest {
        case .lookingUp: "Checking the folder on \(host.displayName)…"
        case .creating: "Creating the folder on \(host.displayName)…"
        }
    }

    private func addFolder() {
        guard !trimmedFolder.isEmpty, runningFolderRequest == nil else { return }
        let folder = trimmedFolder
        let creatingMissingFolder = offersToCreateMissingFolder
        runningFolderRequest = creatingMissingFolder ? .creating : .lookingUp
        errorMessage = nil
        Task {
            do {
                onAdded(
                    try await store.addProjectToSidebar(
                        folder: folder,
                        on: host,
                        creatingMissingFolder: creatingMissingFolder
                    ))
                dismiss()
            } catch RemoteFolderResolutionError.missingFolder {
                missingFolder = folder
            } catch {
                missingFolder = nil
                errorMessage = error.localizedDescription
            }
            runningFolderRequest = nil
        }
    }
}
