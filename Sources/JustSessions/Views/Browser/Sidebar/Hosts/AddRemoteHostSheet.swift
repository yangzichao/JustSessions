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
            Text("Claude Code and Codex sessions on the host are listed under it in the sidebar, and open over SSH. "
                + "Use a Host alias from ~/.ssh/config or user@hostname. `ssh <host>` must work without a password prompt, "
                + "and the host needs rsync. With tmux on the host, sessions keep running when the connection drops "
                + "or the tab closes; resume to reattach.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("devbox or user@devbox.example.com", text: $proposedHost)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addProposedHost)

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
    }

    private func addProposedHost() {
        guard canAddProposedHost else { return }
        store.addRemoteHost(proposedHost)
        dismiss()
    }
}
