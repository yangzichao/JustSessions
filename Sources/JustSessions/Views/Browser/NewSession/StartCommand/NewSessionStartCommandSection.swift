import SwiftUI

/// The command the picked tool's CLI starts with on the picked host: a wrapper, another path, or the CLI with flags
/// of your own. Empty starts the tool as the app does, which the empty field shows, such as `claude` or
/// `kiro-cli chat`. It is kept for the tool's later launches on the host, resumes included; see `CLIStartCommands`.
/// The field stays locked until Edit, and only Save changes the command, going back to the default included. Save keeps
/// a command only once it checks out where the tool runs, so a stray click, keystroke, or typo never changes how the
/// tool starts.
struct NewSessionStartCommandSection: View {
    /// The kept command; empty when the tool starts as the app does.
    let savedCommand: String
    /// What the field holds while it is edited; nil while it is locked.
    @Binding var editedCommand: String?
    let provider: ConversationProvider
    let host: SessionHost
    /// Checks the command where the tool runs, then keeps it; throws when it would not start.
    let onSave: (String) async throws -> Void
    @State private var isChecking = false
    @State private var checkFailure: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Start command")
                    .font(.subheadline.weight(.medium))
                HelpPopoverButton(title: "Start command", explanation: startCommandExplanation)
                    .accessibilityIdentifier("newSession.help.startCommand")
            }
            HStack(spacing: 8) {
                if let editedCommand {
                    editingField
                    // Only empties the field; Save keeps it, and Cancel brings the saved command back.
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
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)
            } else if let checkFailure {
                Text(verbatim: checkFailure)
                    .font(.callout)
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
        TextField(provider.defaultStartCommand, text: Binding(
            get: { editedCommand ?? "" },
            set: {
                editedCommand = $0
                checkFailure = nil
            }
        ))
        .textFieldStyle(ThemedTextFieldStyle())
        .font(.system(.body, design: .monospaced))
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
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(savedCommand.isEmpty ? ThemePalette.tertiaryText : ThemePalette.secondaryText)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedTextFieldSurface()
            .accessibilityLabel("Start command")
    }

    /// Stays in editing with the reason shown when the command would not start.
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
