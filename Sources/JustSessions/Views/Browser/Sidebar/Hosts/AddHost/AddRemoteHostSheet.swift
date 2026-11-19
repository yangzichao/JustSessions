import SwiftUI

struct AddRemoteHostSheet: View {
    let store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loginPrompter = SSHLoginPrompter()
    @State private var proposedHost = ""
    @State private var hostBeingChecked: String?
    @State private var connectionCheck: Task<Void, Never>?
    @State private var failedConnection: FailedConnection?
    @State private var sameMachineCheck: (host: String, result: SSHHostSameMachineCheck)?
    // periphery:ignore - read through its $ binding, which Periphery does not see.
    @State private var showsSetupRequirements = false

    private struct FailedConnection {
        let host: String
        let problem: SSHConnectionProblem
        var afterLoggingIn = false

        var explanation: String {
            afterLoggingIn ? problem.loginFailureExplanation(host: host) : problem.explanationBesideConnect(host: host)
        }
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

    private var hostToAdd: String? {
        guard let host = input.validDestination, !isListed,
            sameMachineCheckOfInput?.listedHostWithSameIdentity == nil
        else { return nil }
        return host
    }

    private var failedConnectionToHostToAdd: FailedConnection? {
        guard let failedConnection, failedConnection.host == hostToAdd else { return nil }
        return failedConnection
    }

    var body: some View {
        ThemeSheetLayout(
            title: Text("Add SSH host"),
            intro: Text("Browse and resume sessions on another machine."),
            width: ThemeSheetMetrics.compactWidth
        ) {
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
                    connectionFailure: failedConnectionToHostToAdd?.explanation
                )
            }

            DisclosureGroup(isExpanded: $showsSetupRequirements) {
                setupRequirements
            } label: {
                ThemeDisclosureTitleButton(isExpanded: $showsSetupRequirements) {
                    Text("Setup requirements")
                }
            }
            .font(ThemeFont.callout)
            .foregroundStyle(ThemePalette.secondaryText)
        } footer: {
            if let hostBeingChecked {
                ProgressView().controlSize(.small)
                Text("Connecting to \(hostBeingChecked)…")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            if let failedConnection = failedConnectionToHostToAdd {
                Button("Add anyway") { add(failedConnection.host) }
            }
            if let failedConnection = failedConnectionToHostToAdd,
                failedConnection.problem.isFixedByLoggingIn || failedConnection.afterLoggingIn
            {
                Button("Connect…") { logInAndAdd(failedConnection.host) }
                    .buttonStyle(ThemeProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(hostBeingChecked != nil)
            } else {
                Button(addButtonTitle, action: checkAndAddHost)
                    .buttonStyle(ThemeProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(hostToAdd == nil || hostBeingChecked != nil)
            }
        }
        .task(id: input.validDestination) { await readWhereTheHostConnects() }
        .sshLoginQuestions(from: loginPrompter)
        .onDisappear { connectionCheck?.cancel() }
    }

    private var addButtonTitle: LocalizedStringKey {
        failedConnectionToHostToAdd == nil ? "Add host" : "Try again"
    }

    private var setupRequirements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SSH aliases come from `~/.ssh/config`.")
            Text("Hosts run Linux or macOS. For Windows, connect to WSL over SSH.")
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
            let sameMachine = await store.sameMachineCheck(for: host)
            guard !Task.isCancelled else { return }
            sameMachineCheck = (host, sameMachine)
            guard sameMachine.listedHostWithSameIdentity == nil else {
                hostBeingChecked = nil
                return
            }
            let problem = await store.connectionProblem(on: host)
            guard !Task.isCancelled else { return }
            hostBeingChecked = nil
            if let problem {
                failedConnection = FailedConnection(host: host, problem: problem)
            } else {
                add(host)
            }
        }
    }

    private func logInAndAdd(_ host: String) {
        guard hostBeingChecked == nil else { return }
        hostBeingChecked = host
        connectionCheck = Task { [loginPrompter] in
            let outcome = await store.logIn(to: host) { await loginPrompter.ask($0) }
            guard !Task.isCancelled else { return }
            hostBeingChecked = nil
            switch outcome {
            case .loggedIn:
                add(host)
            case .cancelled:
                break
            case .failed(let problem):
                failedConnection = FailedConnection(host: host, problem: problem, afterLoggingIn: true)
            }
        }
    }

    private func add(_ host: String) {
        store.addRemoteHost(host)
        dismiss()
    }
}
