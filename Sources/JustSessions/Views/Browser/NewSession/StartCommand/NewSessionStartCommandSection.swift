import SwiftUI

struct NewSessionStartCommandSection: View {
    let savedCommand: String
    @Binding var editedCommand: String?
    let provider: ConversationProvider
    let host: SessionHost
    let onSave: (String) async throws -> Void
    @State private var isChecking = false
    @State private var checkFailure: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Start command")
                    .font(ThemeFont.fieldLabel)
                HelpPopoverButton(title: "Start command", explanation: startCommandExplanation)
                    .accessibilityIdentifier("newSession.help.startCommand")
            }
            HStack(spacing: 8) {
                if let editedCommand {
                    editingField
                    Button("Use default") {
                        self.editedCommand = ""
                        checkFailure = nil
                        isFieldFocused = true
                    }
                    .disabled(isChecking || CLIStartCommands.normalizedCommand(editedCommand).isEmpty)
                    Button("Cancel") {
                        self.editedCommand = nil
                        checkFailure = nil
                    }
                    .disabled(isChecking)
                    Button("Save", action: save)
                        .disabled(isChecking)
                } else {
                    lockedCommand
                    Button("Edit") { editedCommand = savedCommand }
                }
            }
            if isChecking {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    if host == .thisMac {
                        Text("Checking the start command…")
                    } else {
                        Text("Checking the start command on \(host.displayName)…")
                    }
                }
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
            } else if let checkFailure {
                Text(verbatim: checkFailure)
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.errorText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var startCommandExplanation: LocalizedStringKey {
        if host == .thisMac {
            "Also resumes \(provider.rawValue) sessions on this Mac. JustSessions adds its own arguments after it."
        } else {
            "Also resumes \(provider.rawValue) sessions on \(host.displayName). JustSessions adds its own arguments after it."
        }
    }

    private var editingField: some View {
        TextField(
            provider.defaultStartCommand,
            text: Binding(
                get: { editedCommand ?? "" },
                set: {
                    editedCommand = $0
                    checkFailure = nil
                }
            )
        )
        .textFieldStyle(ThemedTextFieldStyle())
        .font(ThemeFont.body.monospaced())
        .autocorrectionDisabled()
        .disabled(isChecking)
        .focused($isFieldFocused)
        .onAppear { isFieldFocused = true }
        .onSubmit(save)
        .accessibilityLabel("Start command")
    }

    /// The kept command, or the tool's own one dimmer when none is kept. Text, not a disabled field: a disabled field
    /// draws its placeholder in the same color as a kept command. A long command wraps, so all its flags show.
    private var lockedCommand: some View {
        Text(verbatim: savedCommand.isEmpty ? provider.defaultStartCommand : savedCommand)
            .font(ThemeFont.body.monospaced())
            .foregroundStyle(savedCommand.isEmpty ? ThemePalette.tertiaryText : ThemePalette.secondaryText)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedTextFieldSurface()
            .accessibilityLabel("Start command")
    }

    private func save() {
        guard let commandToSave = editedCommand, !isChecking else { return }
        isChecking = true
        checkFailure = nil
        Task {
            do {
                try await onSave(commandToSave)
                editedCommand = nil
            } catch {
                checkFailure = error.localizedDescription
            }
            isChecking = false
        }
    }
}
