import AppKit
import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: ConversationProvider
    @State private var selectedHost: SessionHost
    @State private var projectPath: String
    @State private var isStarting = false
    @State private var errorMessage: String?

    let hosts: [SessionHost]
    /// Projects on every host; the menu shows the selected host's.
    let recentProjects: [ProjectConversationGroup]
    let onStart: (ConversationProvider, SessionHost, String) async throws -> Void

    init(
        initialProvider: ConversationProvider,
        initialHost: SessionHost,
        initialProjectPath: String,
        hosts: [SessionHost],
        recentProjects: [ProjectConversationGroup],
        onStart: @escaping (ConversationProvider, SessionHost, String) async throws -> Void
    ) {
        _selectedProvider = State(initialValue: Self.provider(initialProvider, orFirstThatRunsOn: initialHost))
        _selectedHost = State(initialValue: initialHost)
        _projectPath = State(initialValue: initialProjectPath)
        self.hosts = hosts
        self.recentProjects = recentProjects
        self.onStart = onStart
    }

    private var trimmedProjectPath: String {
        projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentProjectsOnSelectedHost: [ProjectConversationGroup] {
        recentProjects.filter { $0.host == selectedHost }
    }

    /// Switching hosts keeps the tool when it runs there and suggests the host's most recent project.
    private var hostSelection: Binding<SessionHost> {
        Binding(
            get: { selectedHost },
            set: { newHost in
                guard newHost != selectedHost else { return }
                selectedHost = newHost
                selectedProvider = Self.provider(selectedProvider, orFirstThatRunsOn: newHost)
                projectPath = recentProjects.first { $0.host == newHost }?.location.path ?? ""
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("New session")
                    .font(.title2.weight(.semibold))
                Text("Start a native CLI in a project folder.")
                    .foregroundStyle(.secondary)
            }

            // The host comes first: it decides which tools can run and which recent projects are offered.
            if hosts.count > 1 {
                Picker("Host", selection: hostSelection) {
                    ForEach(hosts) { host in
                        Label(host.displayName, systemImage: host.symbolName).tag(host)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            Picker("Tool", selection: $selectedProvider) {
                ForEach(ConversationProvider.allCases.filter { $0.runs(on: selectedHost) }) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            projectFolderSection

            HStack(spacing: 8) {
                if isStarting && selectedHost != .thisMac {
                    ProgressView().controlSize(.small)
                    Text("Checking the folder on \(selectedHost.displayName)…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Start session", action: start)
                    .buttonStyle(ProviderProminentButtonStyle(tint: selectedProvider.emphasisTintColor))
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedProjectPath.isEmpty || isStarting)
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

    private var projectFolderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedHost == .thisMac ? "Project folder" : "Project folder on \(selectedHost.displayName)")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                TextField(
                    selectedHost == .thisMac ? "Choose or enter a folder" : "Path on the host, such as ~/code/app",
                    text: $projectPath
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Project folder")
                if selectedHost == .thisMac {
                    Button("Browse…", action: chooseProjectFolder)
                }
            }
            if !recentProjectsOnSelectedHost.isEmpty {
                Menu("Recent projects") {
                    ForEach(Array(recentProjectsOnSelectedHost.prefix(12))) { project in
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

    private func start() {
        let provider = selectedProvider
        let host = selectedHost
        let folder = trimmedProjectPath
        isStarting = true
        Task {
            do {
                try await onStart(provider, host, folder)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isStarting = false
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

    private static func provider(_ provider: ConversationProvider, orFirstThatRunsOn host: SessionHost) -> ConversationProvider {
        provider.runs(on: host) ? provider : ConversationProvider.allCases.first { $0.runs(on: host) } ?? provider
    }
}
