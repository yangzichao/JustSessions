import SwiftUI

/// The command the picked tool's CLI starts with on the picked host: a wrapper, another path, or the CLI with flags
/// of your own. Empty starts the tool's own executable, whose name the empty field shows. It is kept for the tool's
/// later launches on the host, resumes included; see `CLIStartCommands`.
struct NewSessionStartCommandSection: View {
    @Binding var command: String
    let provider: ConversationProvider
    let host: SessionHost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start command")
                .font(.subheadline.weight(.medium))
            TextField(provider.executableName, text: $command)
                .textFieldStyle(ThemedTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .accessibilityLabel("Start command")
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
}
