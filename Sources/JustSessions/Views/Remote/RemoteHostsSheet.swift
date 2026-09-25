import SwiftUI

/// Adds and removes the SSH hosts whose sessions are listed, and shows how each host's last copy went.
struct RemoteHostsSheet: View {
    @ObservedObject var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var proposedHost = ""

    private var canAddProposedHost: Bool {
        guard let host = RemoteHostList.normalizedHost(proposedHost) else { return false }
        return !store.remoteHostList.hosts.contains(host)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Remote hosts").font(.title3.weight(.semibold))
            Text("Sessions saved by Claude Code and Codex on these hosts are listed with your local ones and open over SSH. "
                + "Use a Host alias from ~/.ssh/config or user@hostname. `ssh <host>` must work without a password prompt, "
                + "and the host needs rsync. With tmux on the host, sessions keep running when the connection drops "
                + "or the tab closes; resume to reattach.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("devbox or user@devbox.example.com", text: $proposedHost)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addProposedHost)
                Button("Add", action: addProposedHost)
                    .disabled(!canAddProposedHost)
            }

            if store.remoteHostList.hosts.isEmpty {
                Text("No remote hosts yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.remoteHostList.hosts, id: \.self) { host in
                        RemoteHostRow(
                            host: host,
                            status: store.remoteHostSyncStatuses[host],
                            onRefresh: { store.refreshRemoteHost(host) },
                            onRemove: { store.removeRemoteHost(host) }
                        )
                        if host != store.remoteHostList.hosts.last { Divider() }
                    }
                }
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func addProposedHost() {
        guard canAddProposedHost else { return }
        store.addRemoteHost(proposedHost)
        proposedHost = ""
    }
}

private struct RemoteHostRow: View {
    let host: String
    let status: RemoteHostSyncStatus?
    let onRefresh: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(host).font(.system(size: 13, weight: .medium))
                statusText
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status == .syncing {
                ProgressView().controlSize(.small)
            } else {
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Copy this host's sessions again")
            }
            Button(action: onRemove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Stop listing this host's sessions")
                .accessibilityLabel("Remove \(host)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .syncing:
            Text("Copying sessions…").foregroundStyle(.secondary)
        case .synced(let date):
            Text("Updated \(date, style: .relative) ago").foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        case nil:
            Text("Not copied yet").foregroundStyle(.secondary)
        }
    }
}
