import SwiftUI

/// Adds a folder on an SSH host as a project, from the host's heading. There is no folder picker for another machine,
/// so the path is typed and looked up on the host. When the host reports the folder missing, the sheet offers to
/// create it there, so a typo is never created without a second look.
struct AddProjectOnSSHHostSheet: View {
    @ObservedObject var store: ConversationStore
    let host: SessionHost
    /// Called with the project's key once it is listed.
    let onAdded: (String) -> Void

    private enum FolderRequest {
        case lookingUp
        case creating
    }

    @Environment(\.dismiss) private var dismiss
    @State private var folder = ""
    @State private var runningFolderRequest: FolderRequest?
    /// The folder as typed when the host reported it missing. Editing the path withdraws the offer to create it.
    @State private var missingFolder: String?
    @State private var errorMessage: String?

    private var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var offersToCreateMissingFolder: Bool {
        missingFolder != nil && missingFolder == trimmedFolder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add project").font(.title3.weight(.semibold))
            Text("The folder is listed under \(host.displayName) in the sidebar, ready for new sessions.")
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Project folder on \(host.displayName)")
                    .font(.subheadline.weight(.medium))
                TextField("Path on the host, such as ~/code/app", text: $folder)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .accessibilityLabel("Project folder")
                    .onSubmit(addFolder)
                if offersToCreateMissingFolder {
                    Text("There is no folder \(trimmedFolder) on \(host.displayName). Create it to add the project.")
                        .font(.callout)
                        .foregroundStyle(ThemePalette.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(.callout)
                        .foregroundStyle(ThemePalette.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                if let runningFolderRequest {
                    ProgressView().controlSize(.small)
                    Text(progressText(for: runningFolderRequest))
                        .font(.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(addButtonTitle, action: addFolder)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedFolder.isEmpty || runningFolderRequest != nil)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(ThemePalette.contentSurface)
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
                onAdded(try await store.addProjectToSidebar(
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
