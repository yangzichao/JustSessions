import AppKit
import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedProvider: ConversationProvider
    @State private var selectedHost: SessionHost
    @State private var projectPath: String
    @State private var isStarting = false
    @State private var errorMessage: String?

    let hosts: [SessionHost]
    /// The tools installed on each host; the picker offers the selected host's.
    let providersByHost: [SessionHost: [ConversationProvider]]
    /// Projects on every host; the menu shows the selected host's.
    let recentProjects: [ProjectConversationGroup]
    let onStart: (ConversationProvider, SessionHost, String) async throws -> Void

    init(
        initialProvider: ConversationProvider,
        initialHost: SessionHost,
        initialProjectPath: String,
        hosts: [SessionHost],
        providersByHost: [SessionHost: [ConversationProvider]],
        recentProjects: [ProjectConversationGroup],
        onStart: @escaping (ConversationProvider, SessionHost, String) async throws -> Void
    ) {
        _selectedProvider = State(initialValue: initialProvider)
        _selectedHost = State(initialValue: initialHost)
        _projectPath = State(initialValue: initialProjectPath)
        self.hosts = hosts
        self.providersByHost = providersByHost
        self.recentProjects = recentProjects
        self.onStart = onStart
    }

    private var providersOnSelectedHost: [ConversationProvider] {
        providersByHost[selectedHost] ?? []
    }

    /// The picked tool while the host has it, or else the host's first. Hosts are checked as they refresh, so the
    /// list can change while the sheet is open. Nil when the host has none.
    private var startingProvider: ConversationProvider? {
        providersOnSelectedHost.contains(selectedProvider) ? selectedProvider : providersOnSelectedHost.first
    }

    private var providerSelection: Binding<ConversationProvider> {
        Binding(
            get: { startingProvider ?? selectedProvider },
            set: { selectedProvider = $0 }
        )
    }

    private var trimmedProjectPath: String {
        projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentProjectsOnSelectedHost: [ProjectConversationGroup] {
        recentProjects.filter { $0.host == selectedHost }
    }

    /// Switching hosts keeps the tool when the host has it and suggests the host's most recent project.
    private var hostSelection: Binding<SessionHost> {
        Binding(
            get: { selectedHost },
            set: { newHost in
                guard newHost != selectedHost else { return }
                selectedHost = newHost
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
                        Label {
                            if host == .thisMac { Text("This Mac") }
                            else { Text(verbatim: host.displayName) }
                        } icon: { Image(systemName: host.symbolName) }
                        .tag(host)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            if providersOnSelectedHost.isEmpty {
                Label(NewSessionProviderAvailability.noCLIFoundMessage(on: selectedHost, language: AppInterfaceLanguage(identifier: locale.identifier)), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker("Tool", selection: providerSelection) {
                    ForEach(providersOnSelectedHost) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

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
                    .buttonStyle(ProviderProminentButtonStyle(tint: (startingProvider ?? selectedProvider).emphasisTintColor))
                    .keyboardShortcut(.defaultAction)
                    .disabled(startingProvider == nil || trimmedProjectPath.isEmpty || isStarting)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(ThemePalette.contentSurface)
        .alert("Could not start session", isPresented: Binding(isPresenting: $errorMessage)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage { Text(verbatim: errorMessage) }
            else { Text("Unknown error") }
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
                .textFieldStyle(ThemedTextFieldStyle())
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
        guard let provider = startingProvider else { return }
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
        panel.prompt = AppLocalization.string("Choose")
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
