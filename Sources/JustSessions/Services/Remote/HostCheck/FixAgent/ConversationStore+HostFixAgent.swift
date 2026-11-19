import Foundation

/// Fix with agent… in the host check sheet starts a CLI session whose first message is the check's report, how
/// JustSessions uses the host, and the guide sections about what the check found; see `HostFixAgentPrompt`. It runs on
/// the checked host, or on this Mac when the host can't start a CLI, and outside tmux, which may be what is broken.
extension ConversationStore {
    static let lastHostFixAgentProviderKey = "hostFixAgentProvider"

    /// The tools the agent can be on the machine: on the host, those the check didn't find failing.
    func hostFixAgentProviders(on machine: HostFixAgentMachine, report: HostCheckReport) -> [ConversationProvider] {
        switch machine {
        case .thisMac:
            return newSessionProviders(on: .thisMac)
        case .checkedHost:
            return newSessionProviders(on: .ssh(report.host)).filter { provider in
                !report.findings.contains { $0.id == "cli-\(provider.executableName)" && $0.status == .problem }
            }
        }
    }

    /// The form as it first shows: on this Mac when the host's login shell or its CLIs can't start an agent, with
    /// the tool started last time when the machine has it.
    func hostFixAgentDraft(for state: HostCheckSheetState, report: HostCheckReport) -> HostFixAgentDraft {
        let hostCantStartAgent = report.findings.contains {
            $0.status == .problem && ["connection", "login-shell", "shell-startup"].contains($0.id)
        }
        let machine: HostFixAgentMachine =
            hostCantStartAgent || hostFixAgentProviders(on: .checkedHost, report: report).isEmpty
            ? .thisMac
            : .checkedHost
        return HostFixAgentDraft(
            machine: machine,
            provider: preferredHostFixAgentProvider(among: hostFixAgentProviders(on: machine, report: report)),
            task: HostFixAgentPrompt.task(for: report, facts: hostFixAgentFacts(for: state, report: report)),
            guideSections: Set(JustSessionsGuideSection.sections(about: report))
        )
    }

    func preferredHostFixAgentProvider(among providers: [ConversationProvider]) -> ConversationProvider? {
        let lastProvider = userDefaults.string(forKey: Self.lastHostFixAgentProviderKey).flatMap(ConversationProvider.init)
        if let lastProvider, providers.contains(lastProvider) { return lastProvider }
        return providers.first
    }

    /// The folder the agent starts in, as typed in the New session sheet: the tab's folder on the host, when the
    /// check came from a tab and found its folder, or else the home folder.
    func hostFixAgentFolder(on machine: HostFixAgentMachine, for state: HostCheckSheetState, report: HostCheckReport) -> String {
        guard machine == .checkedHost, let session = state.session,
            report.findings.contains(where: { $0.id == "folder" && $0.status == .passed })
        else { return "~" }
        return session.projectPath
    }

    /// Opens the agent's tab; the sheet closes once it opens.
    func startHostFixAgent(
        _ draft: HostFixAgentDraft,
        for state: HostCheckSheetState,
        report: HostCheckReport,
        resolver: RemoteFolderResolver = RemoteFolderResolver()
    ) async throws {
        guard let provider = draft.provider else { return }
        let host: SessionHost = draft.machine == .thisMac ? .thisMac : .ssh(report.host)
        let location = try await projectLocation(
            of: hostFixAgentFolder(on: draft.machine, for: state, report: report),
            on: host,
            resolver: resolver
        )
        let message = HostFixAgentPrompt.message(
            task: draft.task,
            machine: draft.machine,
            host: report.host,
            folder: location.path,
            guideSections: JustSessionsGuideSection.all.filter(draft.guideSections.contains),
            appVersion: FeedbackEnvironment.current.appVersion
        )
        if case .ssh(let destination) = host {
            let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
                provider: provider,
                projectPath: location.path,
                arguments: provider.initialPromptArguments(message),
                shellStartup: RemoteHostShellStartups.shared.startup(on: destination),
                cliLocation: RemoteHostCLILocations.shared.location(of: provider, on: destination)
            )
            guard remoteCommand.utf8.count <= HostFixAgentError.longestRemoteCommandByteCount else {
                throw HostFixAgentError.promptTooLong(host: destination)
            }
        }
        try launchNewSession(provider: provider, in: location, initialPrompt: message, runsInTmux: false)
        userDefaults.set(provider.rawValue, forKey: Self.lastHostFixAgentProviderKey)
        if hostCheck?.id == state.id { hostCheck = nil }
    }

    private func hostFixAgentFacts(for state: HostCheckSheetState, report: HostCheckReport) -> HostFixAgentHostFacts {
        let host = report.host
        return HostFixAgentHostFacts(
            host: host,
            shellStartup: RemoteHostShellStartups.shared.startup(on: host),
            usesHostTmuxPrefix: usesTmuxPrefix(on: .ssh(host)),
            runningTmuxSessionNames: tmuxSessionNamesByHost[.ssh(host)],
            tmuxServerProblem: tmuxServerProblemsByHost[host],
            session: state.session
        )
    }
}

enum HostFixAgentError: LocalizedError, Equatable {
    case promptTooLong(host: String)

    /// Linux takes at most 128 KiB in one argument, and the host's shell gets the whole command as one; the rest is
    /// room for the shell's own quoting.
    static let longestRemoteCommandByteCount = 120_000

    var errorDescription: String? {
        switch self {
        case .promptTooLong(let host):
            AppLocalization.string("The prompt is too long to send to \(host). Leave out a guide section, or shorten the prompt.")
        }
    }
}
