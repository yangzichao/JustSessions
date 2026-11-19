import SwiftUI

struct NewSessionDeleteWhenClosedToggle: View {
    @Binding var deletesSessionWhenClosed: Bool
    let provider: ConversationProvider
    let host: SessionHost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Toggle("Delete the session when its tab closes", isOn: $deletesSessionWhenClosed)
                    .toggleStyle(ThemedCheckboxToggleStyle())
                HelpPopoverButton(
                    title: "Deleting when the tab closes",
                    explanation:
                        "Closing the tab ends the CLI and deletes the session without asking again. Closing the window or quitting JustSessions keeps it until its tab closes. Keep session in the tab's menu keeps it after all."
                )
            }
            if deletesSessionWhenClosed {
                whereTheSessionGoes
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var whereTheSessionGoes: Text {
        if let sshDestination = host.sshDestination {
            return Text("It is deleted permanently on \(sshDestination). SSH hosts have no Trash.")
        }
        switch provider {
        case .claude, .antigravity, .pi:
            return Text("It moves to the Trash.")
        case .codex, .kiro, .opencode:
            return Text("\(provider.rawValue) deletes it permanently.")
        }
    }
}
