import SwiftUI

/// Adds an SSH host. Its sessions are listed under a heading of their own, below this Mac's; refreshing and
/// removing it are on that heading's right-click menu. What is typed is read as `ssh` would read it, so a pasted
/// `ssh devbox` adds `devbox`, a port is shown how to put in `~/.ssh/config`, and a host that connects where a listed
/// one does is refused. Adding first logs in to the host as the app's background commands do, so a host they can't
/// reach says why here; Add anyway keeps it, as for a host that is only offline now.
struct AddRemoteHostSheet: View {
    @ObservedObject var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var proposedHost = ""
    /// The host being logged in to before it is added. The field is locked meanwhile.
    @State private var hostBeingChecked: String?
    @State private var connectionCheck: Task<Void, Never>?
    /// Why the host could not be reached. Editing the host withdraws it, and with it Add anyway.
    @State private var failedConnection: FailedConnection?
    /// Where the typed host connects, read by `ssh -G` shortly after typing stops.
    @State private var sameMachineCheck: (host: String, result: SSHHostSameMachineCheck)?

    private struct FailedConnection {
        let host: String
        let problem: SSHConnectionProblem
    }

    private var input: RemoteHostInput {
        RemoteHostInput(proposedHost)
    }

    private var isListed: Bool {
        input.validDestination.map(store.remoteHostList.hosts.contains) ?? false
    }

    private var sameMachineCheckOfInput: SSHHostSameMachineCheck? {
        guard let sameMachineCheck, sameMachineCheck.host == input.validDestination else { return nil }
        return sameMachineCheck.result
    }

    /// The host as it will be stored, or nil when it is invalid or already listed, under its name or another.
    private var hostToAdd: String? {
        guard let host = input.validDestination, !isListed,
              sameMachineCheckOfInput?.listedHostWithSameIdentity == nil else { return nil }
        return host
    }

    private var failedConnectionToHostToAdd: FailedConnection? {
        guard let failedConnection, failedConnection.host == hostToAdd else { return nil }
        return failedConnection
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
                    .disabled(hostBeingChecked != nil)
                    .onSubmit(checkAndAddHost)
                AddRemoteHostFieldNote(
                    input: input,
                    isListed: isListed,
                    sameMachineCheck: sameMachineCheckOfInput,
                    failedConnection: failedConnectionToHostToAdd.map { ($0.host, $0.problem) }
                )
            }

            DisclosureGroup("Setup requirements") {
                setupRequirements
            }
            .font(.callout)
            .foregroundStyle(ThemePalette.secondaryText)

            HStack(spacing: 8) {
                if let hostBeingChecked {
                    ProgressView().controlSize(.small)
                    Text("Connecting to \(hostBeingChecked)…")
                        .font(.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if let failedConnection = failedConnectionToHostToAdd {
                    Button("Add anyway") { add(failedConnection.host) }
                }
                Button(addButtonTitle, action: checkAndAddHost)
                    .keyboardShortcut(.defaultAction)
                    .disabled(hostToAdd == nil || hostBeingChecked != nil)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(ThemePalette.contentSurface)
        .task(id: input.validDestination) { await readWhereTheHostConnects() }
        .onDisappear { connectionCheck?.cancel() }
    }

    private var addButtonTitle: LocalizedStringKey {
        failedConnectionToHostToAdd == nil ? "Add host" : "Try again"
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

    /// Waits for typing to pause; a new host cancels the wait.
    private func readWhereTheHostConnects() async {
        guard let host = input.validDestination, !isListed else { return }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let result = await store.sameMachineCheck(for: host)
        guard !Task.isCancelled else { return }
        sameMachineCheck = (host, result)
    }

    private func checkAndAddHost() {
        guard let host = hostToAdd, hostBeingChecked == nil else { return }
        hostBeingChecked = host
        failedConnection = nil
        connectionCheck = Task {
            // Return can come before the read that follows typing.
            let sameMachine = await store.sameMachineCheck(for: host)
            guard !Task.isCancelled else { return }
            sameMachineCheck = (host, sameMachine)
            guard sameMachine.listedHostWithSameIdentity == nil else {
                hostBeingChecked = nil
                return
            }
            let problem = await store.connectionProblem(on: host)
            // Cancel, or a click outside the sheet, closed it during the check.
            guard !Task.isCancelled else { return }
            hostBeingChecked = nil
            if let problem {
                failedConnection = FailedConnection(host: host, problem: problem)
            } else {
                add(host)
            }
        }
    }

    private func add(_ host: String) {
        store.addRemoteHost(host)
        dismiss()
    }
}
