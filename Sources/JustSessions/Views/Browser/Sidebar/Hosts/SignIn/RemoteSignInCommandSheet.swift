import SwiftUI

struct RemoteSignInCommandSheet: View {
    let host: String
    let needsLogIn: Bool
    var signIns: RemoteSignIns = .shared

    @Environment(\.dismiss) private var dismiss
    @State private var command = ""
    @State private var checkCommand = ""
    @State private var intervalHours = RemoteSignInCommand.defaultIntervalHours

    private var hasCommand: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCheckCommand: Bool {
        !checkCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ThemeSheetLayout(
            title: Text("Sign-in command"),
            intro: Text(
                "Signs in again on \(host) when a sign-in there expires. When the command asks for a PIN or a code, JustSessions asks you in a dialog."
            ),
            width: ThemeSheetMetrics.compactWidth
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command")
                        .font(ThemeFont.fieldLabel)
                    TextField("Command", text: $command, prompt: Text(verbatim: "kinit"))
                        .textFieldStyle(ThemedTextFieldStyle())
                        .font(ThemeFont.body.monospaced())
                        .onSubmit(save)
                    Text("Runs on the host in your login shell, as you'd type it there.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check command (optional)")
                        .font(ThemeFont.fieldLabel)
                    TextField("Check command", text: $checkCommand, prompt: Text(verbatim: "klist -s"))
                        .textFieldStyle(ThemedTextFieldStyle())
                        .font(ThemeFont.body.monospaced())
                        .onSubmit(save)
                    Text("Runs every 5 minutes. When it exits with anything but 0, you're asked to sign in.")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !hasCheckCommand {
                    Picker("Without a check command, sign in every", selection: $intervalHours) {
                        ForEach(RemoteSignInCommand.intervalChoices, id: \.self) { hours in
                            Text("\(hours) hours").tag(hours)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        } footer: {
            if signIns.command(on: host) != nil {
                Button("Remove", role: .destructive) {
                    signIns.setCommand(nil, on: host)
                    dismiss()
                }
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save", action: save)
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!hasCommand)
        }
        .onAppear(perform: loadSavedCommand)
    }

    private func loadSavedCommand() {
        guard let saved = signIns.command(on: host) else { return }
        command = saved.command
        checkCommand = saved.checkCommand ?? ""
        intervalHours = saved.intervalHours
    }

    private func save() {
        guard
            let signInCommand = RemoteSignInCommand(
                command: command,
                checkCommand: checkCommand,
                intervalHours: intervalHours
            )
        else { return }
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if signIns.command(on: host) != signInCommand {
                signIns.setCommand(signInCommand, on: host, needsLogIn: needsLogIn)
            }
        }
    }
}
