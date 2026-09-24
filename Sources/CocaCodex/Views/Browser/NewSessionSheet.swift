import AppKit
import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: ConversationProvider
    @State private var projectPath: String
    @State private var errorMessage: String?

    let recentProjects: [ProjectConversationGroup]
    let onStart: (ConversationProvider, String) throws -> Void

    init(
        initialProvider: ConversationProvider,
        initialProjectPath: String,
        recentProjects: [ProjectConversationGroup],
        onStart: @escaping (ConversationProvider, String) throws -> Void
    ) {
        _selectedProvider = State(initialValue: initialProvider)
        _projectPath = State(initialValue: initialProjectPath)
        self.recentProjects = recentProjects
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("New session")
                    .font(.title2.weight(.semibold))
                Text("Start a native CLI in a project folder.")
                    .foregroundStyle(.secondary)
            }

            Picker("Tool", selection: $selectedProvider) {
                ForEach(ConversationProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Project folder")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    TextField("Choose or enter a folder", text: $projectPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Project folder")
                    Button("Browse…", action: chooseProjectFolder)
                }
                if !recentProjects.isEmpty {
                    Menu("Recent projects") {
                        ForEach(Array(recentProjects.prefix(12))) { project in
                            Button("\(project.projectName) — \(project.projectPath)") {
                                projectPath = project.projectPath
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Start session") {
                    do {
                        try onStart(selectedProvider, projectPath.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .alert("Could not start session", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if FileManager.default.fileExists(atPath: projectPath) {
            panel.directoryURL = URL(fileURLWithPath: projectPath)
        }
        panel.begin { response in
            if response == .OK, let selectedFolder = panel.url {
                projectPath = selectedFolder.path
            }
        }
    }
}
