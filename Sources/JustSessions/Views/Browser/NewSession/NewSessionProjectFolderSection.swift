import SwiftUI

struct NewSessionProjectFolderSection: View {
    @Binding var projectPath: String
    let host: SessionHost
    let recentProjects: [ProjectConversationGroup]
    let missingFolder: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(host == .thisMac ? "Project folder" : "Project folder on \(host.displayName)")
                .font(ThemeFont.fieldLabel)
            HStack(spacing: 8) {
                TextField(
                    host == .thisMac ? "Choose or enter a folder" : "Path on the host, such as ~/code/app",
                    text: $projectPath
                )
                .textFieldStyle(ThemedTextFieldStyle())
                .accessibilityLabel("Project folder")
                if host == .thisMac {
                    Button("Browse…", action: chooseProjectFolder)
                }
            }
            if let missingFolder {
                missingFolderNote(missingFolder)
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.warningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !recentProjects.isEmpty {
                Menu("Recent projects") {
                    ForEach(Array(recentProjects.prefix(12))) { project in
                        Button("\(project.displayName) — \(project.location.path)") {
                            projectPath = project.location.path
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private func missingFolderNote(_ folder: String) -> Text {
        host == .thisMac
            ? Text("There is no folder \(folder) on this Mac. Check the path, or create the folder.")
            : Text("There is no folder \(folder) on \(host.displayName). Check the path, or create the folder.")
    }

    private func chooseProjectFolder() {
        ProjectFolderPanel.choose(prompt: AppLocalization.string("Choose"), startingAt: projectPath) { chosenFolder in
            projectPath = chosenFolder
        }
    }
}
