import SwiftUI

struct NewSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedKind: NewSessionKind
    @State private var selectedHost: SessionHost
    @State private var projectPath: String
    @State private var isStarting = false
    @State private var isCreatingMissingFolder = false
    @State private var deletesSessionWhenClosed = false
    /// The folder as typed, on its host, when the host reported it missing. Editing the path or switching hosts
    /// withdraws the offer to create it.
    @State private var missingFolder: MissingFolder?
    @State private var errorMessage: String?
    /// Start commands being edited, per tool and host, so switching back to a tool shows the edit in progress.
    @State private var editedStartCommands: [StartCommandTarget: String] = [:]

    let hosts: [SessionHost]
    /// The tools installed on each host; the picker offers the selected host's.
    let providersByHost: [SessionHost: [ConversationProvider]]
    /// Projects on every host; the menu shows the selected host's.
    let recentProjects: [ProjectConversationGroup]
    /// The kept start commands, which the locked field shows.
    let startCommands: CLIStartCommands
    /// Checks a start command where the tool runs, then keeps it; throws when it would not start.
    let onSaveStartCommand: (_ command: String, _ provider: ConversationProvider, _ host: SessionHost) async throws -> Void
    let onStart: (NewSessionRequest) async throws -> Void

    init(
        initialKind: NewSessionKind,
        initialHost: SessionHost,
        initialProjectPath: String,
        hosts: [SessionHost],
        providersByHost: [SessionHost: [ConversationProvider]],
        recentProjects: [ProjectConversationGroup],
        startCommands: CLIStartCommands,
        onSaveStartCommand: @escaping (_ command: String, _ provider: ConversationProvider, _ host: SessionHost) async throws -> Void,
        onStart: @escaping (NewSessionRequest) async throws -> Void
    ) {
        _selectedKind = State(initialValue: initialKind)
        _selectedHost = State(initialValue: initialHost)
        _projectPath = State(initialValue: initialProjectPath)
        self.hosts = hosts
        self.providersByHost = providersByHost
        self.recentProjects = recentProjects
        self.startCommands = startCommands
        self.onSaveStartCommand = onSaveStartCommand
        self.onStart = onStart
    }

    private var providersOnSelectedHost: [ConversationProvider] {
        providersByHost[selectedHost] ?? []
    }

    /// A picked tool while the host has it, or else the host's first. Hosts are checked as they refresh, so the list
    /// can change while the sheet is open. A terminal when picked or when the host has no tool.
    private var startingKind: NewSessionKind {
        guard case .cli(let provider) = selectedKind else { return .plainTerminal }
        if providersOnSelectedHost.contains(provider) { return selectedKind }
        return providersOnSelectedHost.first.map(NewSessionKind.cli) ?? .plainTerminal
    }

    private var kindSelection: Binding<NewSessionKind> {
        Binding(
            get: { startingKind },
            set: { selectedKind = $0 }
        )
    }

    private func editedStartCommandBinding(for provider: ConversationProvider) -> Binding<String?> {
        let target = StartCommandTarget(provider: provider, host: selectedHost)
        return Binding(
            get: { editedStartCommands[target] },
            set: { editedStartCommands[target] = $0 }
        )
    }

    /// A session starts with the kept command, so it waits until an edit to the shown one is saved or cancelled.
    private var isEditingShownStartCommand: Bool {
        guard case .cli(let provider) = startingKind else { return false }
        return editedStartCommands[StartCommandTarget(provider: provider, host: selectedHost)] != nil
    }

    private var trimmedProjectPath: String {
        projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var recentProjectsOnSelectedHost: [ProjectConversationGroup] {
        recentProjects.filter { $0.host == selectedHost }
    }

    private var offersToCreateMissingFolder: Bool {
        missingFolder == MissingFolder(host: selectedHost, folder: trimmedProjectPath)
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
        ThemeSheetLayout(
            title: Text("New session"),
            intro: Text("Start a native CLI or a plain terminal in a project folder."),
            width: ThemeSheetMetrics.regularWidth
        ) {
            // The host comes first: it decides which tools can run and which recent projects are offered.
            if hosts.count > 1 {
                Picker("Host", selection: hostSelection) {
                    ForEach(hosts) { host in
                        Label {
                            if host == .thisMac { Text("This Mac") } else { Text(verbatim: host.displayName) }
                        } icon: {
                            Image(systemName: host.symbolName)
                        }
                        .tag(host)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            NewSessionKindPicker(
                selection: kindSelection,
                providers: providersOnSelectedHost,
                noCLIFoundMessage: NewSessionProviderAvailability.noCLIFoundMessage(
                    on: selectedHost, language: AppInterfaceLanguage(identifier: locale.identifier))
            )

            if case .cli(let provider) = startingKind {
                NewSessionStartCommandSection(
                    savedCommand: startCommands.customCommand(for: provider, on: selectedHost) ?? "",
                    editedCommand: editedStartCommandBinding(for: provider),
                    provider: provider,
                    host: selectedHost,
                    onSave: { [selectedHost] in try await onSaveStartCommand($0, provider, selectedHost) }
                )
                // A check in progress or its failure belongs to one tool on one host.
                .id(StartCommandTarget(provider: provider, host: selectedHost))
            }

            NewSessionProjectFolderSection(
                projectPath: $projectPath,
                host: selectedHost,
                recentProjects: recentProjectsOnSelectedHost,
                missingFolder: offersToCreateMissingFolder ? trimmedProjectPath : nil
            )

            if case .cli(let provider) = startingKind {
                NewSessionDeleteWhenClosedToggle(
                    deletesSessionWhenClosed: $deletesSessionWhenClosed,
                    provider: provider,
                    host: selectedHost
                )
            }
        } footer: {
            if isStarting && selectedHost != .thisMac {
                ProgressView().controlSize(.small)
                Text(
                    isCreatingMissingFolder
                        ? "Creating the folder on \(selectedHost.displayName)…"
                        : "Checking the folder on \(selectedHost.displayName)…"
                )
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(startButtonTitle, action: start)
                .buttonStyle(ProviderProminentButtonStyle(tint: startingKind.emphasisTintColor))
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedProjectPath.isEmpty || isStarting || isEditingShownStartCommand)
        }
        .alert(
            startingKind == .plainTerminal ? "Could not open terminal" : "Could not start session",
            isPresented: Binding(isPresenting: $errorMessage)
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage { Text(verbatim: errorMessage) } else { Text("Unknown error") }
        }
        // The alert covers this sheet, so a click on the sheet around it closes only the alert.
        .dismissesOnClickOutside(item: $errorMessage)
    }

    private var startButtonTitle: LocalizedStringKey {
        switch (startingKind == .plainTerminal, offersToCreateMissingFolder) {
        case (true, true): "Create folder and open terminal"
        case (true, false): "Open terminal"
        case (false, true): "Create folder and start"
        case (false, false): "Start session"
        }
    }

    private func start() {
        let request = NewSessionRequest(
            kind: startingKind,
            host: selectedHost,
            folder: trimmedProjectPath,
            creatingMissingFolder: offersToCreateMissingFolder,
            deletesSessionWhenClosed: startingKind != .plainTerminal && deletesSessionWhenClosed
        )
        isStarting = true
        isCreatingMissingFolder = request.creatingMissingFolder
        Task {
            do {
                try await onStart(request)
                dismiss()
            } catch RemoteFolderResolutionError.missingFolder, ThisMacFolderResolutionError.missingFolder {
                missingFolder = MissingFolder(host: request.host, folder: request.folder)
            } catch {
                missingFolder = nil
                errorMessage = error.localizedDescription
            }
            isStarting = false
            isCreatingMissingFolder = false
        }
    }
}

/// A folder the host reported missing, as typed.
private struct MissingFolder: Equatable {
    let host: SessionHost
    let folder: String
}

/// A tool on a host, whose start command edit the sheet keeps while it is open.
private struct StartCommandTarget: Hashable {
    let provider: ConversationProvider
    let host: SessionHost
}
