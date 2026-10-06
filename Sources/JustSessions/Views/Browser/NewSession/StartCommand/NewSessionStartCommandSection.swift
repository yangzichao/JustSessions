import SwiftUI

/// The command the picked tool's CLI starts with on the picked host: a wrapper, another path, or the CLI with flags
/// of your own. Empty starts the tool as the app does, which the empty field shows, such as `claude` or
/// `kiro-cli chat`. It is kept for the tool's later launches on the host, resumes included; see `CLIStartCommands`.
/// The field stays locked until Edit and changes the kept command only on Save, so a stray keystroke in the sheet
/// never changes how the tool starts.
struct NewSessionStartCommandSection: View {
    /// The kept command; empty when the tool starts as the app does.
    let savedCommand: String
    /// What the field holds while it is edited; nil while it is locked.
    @Binding var editedCommand: String?
    let provider: ConversationProvider
    let host: SessionHost
    let onSave: (String) -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start command")
                .font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                if editedCommand != nil {
                    TextField(provider.defaultStartCommand, text: Binding(
                        get: { editedCommand ?? "" },
                        set: { editedCommand = $0 }
                    ))
                    .textFieldStyle(ThemedTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .onAppear { isFieldFocused = true }
                    .onSubmit(save)
                    .accessibilityLabel("Start command")
                    Button("Cancel") { editedCommand = nil }
                    Button("Save", action: save)
                } else {
                    lockedCommand
                    Button("Edit") { editedCommand = savedCommand }
                }
            }
            Group {
                if host == .thisMac {
                    Text("Also resumes \(provider.rawValue) sessions on this Mac. JustSessions adds its own arguments after it.")
                } else {
                    Text("Also resumes \(provider.rawValue) sessions on \(host.displayName). JustSessions adds its own arguments after it.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The kept command, or the tool's own one dimmer when none is kept. Text, not a disabled field: a disabled field
    /// draws its placeholder in the same color as a kept command.
    private var lockedCommand: some View {
        Text(verbatim: savedCommand.isEmpty ? provider.defaultStartCommand : savedCommand)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(savedCommand.isEmpty ? HierarchicalShapeStyle.tertiary : .secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedTextFieldSurface()
            .accessibilityLabel("Start command")
    }

    private func save() {
        guard let editedCommand else { return }
        onSave(editedCommand)
        self.editedCommand = nil
    }
}
