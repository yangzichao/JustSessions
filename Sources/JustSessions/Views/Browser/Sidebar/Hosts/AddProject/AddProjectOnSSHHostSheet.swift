import SwiftUI

/// Adds a folder on an SSH host as a project, from the host's heading. There is no folder picker for another machine,
/// so the path is typed and looked up on the host, which reports a folder that is missing.
struct AddProjectOnSSHHostSheet: View {
    @ObservedObject var store: ConversationStore
    let host: SessionHost
    /// Called with the project's key once it is listed.
    let onAdded: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folder = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    private var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
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
                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(.callout)
                        .foregroundStyle(ThemePalette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                if isChecking {
                    ProgressView().controlSize(.small)
                    Text("Checking the folder on \(host.displayName)…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add project", action: addFolder)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedFolder.isEmpty || isChecking)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(ThemePalette.contentSurface)
    }

    private func addFolder() {
        guard !trimmedFolder.isEmpty, !isChecking else { return }
        let folder = trimmedFolder
        isChecking = true
        errorMessage = nil
        Task {
            do {
                onAdded(try await store.addProjectToSidebar(folder: folder, on: host))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isChecking = false
        }
    }
}
