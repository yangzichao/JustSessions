import SwiftUI

/// Adds an SSH host. Its sessions are listed under a heading of their own, below this Mac's; refreshing and
/// removing it are on that heading's right-click menu.
struct AddRemoteHostSheet: View {
    @ObservedObject var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var proposedHost = ""

    private var canAddProposedHost: Bool {
        guard let host = RemoteHostList.normalizedHost(proposedHost) else { return false }
        return !store.remoteHostList.hosts.contains(host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add SSH host").font(.title3.weight(.semibold))
            Text("Browse and resume sessions on another machine.")
                .font(.callout)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                TextField("SSH alias or user@hostname", text: $proposedHost)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .accessibilityLabel("SSH host")
                    .onSubmit(addProposedHost)
                Text("Requires passwordless SSH.")
                    .font(.caption)
                    .foregroundStyle(ThemePalette.secondaryText)
            }

            DisclosureGroup("Setup requirements") {
                setupRequirements
            }
            .font(.callout)
            .foregroundStyle(ThemePalette.secondaryText)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add host", action: addProposedHost)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAddProposedHost)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(ThemePalette.contentSurface)
    }

    private var setupRequirements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SSH aliases come from `~/.ssh/config`.")
            Text("Install `rsync` and the CLIs you use on the host.")
            Text("For sessions to survive disconnects or closed tabs, install `tmux` on the host. Reopen a session to reattach.")
            Text("Antigravity and OpenCode need `python3`; deleting Antigravity sessions also needs `lsof`.")
            Link("SSH setup guide ↗", destination: AppLinks.userGuideSSHHostsURL)
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func addProposedHost() {
        guard canAddProposedHost else { return }
        store.addRemoteHost(proposedHost)
        dismiss()
    }
}
