import AppKit
import SwiftUI

struct HostCheckCommandToRunYourself: View {
    let command: String
    @State private var hasCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Run it yourself in Terminal:")
                    .font(ThemeFont.detail)
                    .foregroundStyle(ThemePalette.tertiaryText)
                Spacer()
                Button(hasCopied ? "Copied" : "Copy", systemImage: hasCopied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    hasCopied = NSPasteboard.general.setString(command, forType: .string)
                }
                .buttonStyle(ThemePlainButtonStyle(horizontalPadding: 4, verticalPadding: 2))
                .font(ThemeFont.caption)
                .help("Copy the command")
                .accessibilityLabel("Copy the command")
            }
            HostCheckMonospacedText(text: command)
        }
    }
}
