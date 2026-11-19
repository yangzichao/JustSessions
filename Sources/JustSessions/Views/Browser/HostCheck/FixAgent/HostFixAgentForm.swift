import SwiftUI

/// Fix with agent…'s page of the host check sheet: where the agent runs, which CLI, the prompt to edit, and the
/// guide sections it ends with. The sheet's footer starts it; see `ConversationStore+HostFixAgent`.
struct HostFixAgentForm: View {
    @Binding var draft: HostFixAgentDraft
    let host: String
    /// The tools the agent can be on each machine.
    let providers: (HostFixAgentMachine) -> [ConversationProvider]
    /// The tool to pick when the machine changes.
    let preferredProvider: ([ConversationProvider]) -> ConversationProvider?
    /// Where the agent starts on each machine, as typed in the New session sheet.
    let folder: (HostFixAgentMachine) -> String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("Run on") {
                ThemeSegmentedPicker(
                    "Run on", selection: $draft.machine,
                    segments: [
                        ThemeSegment(value: HostFixAgentMachine.checkedHost, title: Text(verbatim: host)),
                        ThemeSegment(value: HostFixAgentMachine.thisMac, title: Text("This Mac")),
                    ]
                )
                .fixedSize()
                Text(machineExplanation)
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
                    .lineLimit(2)
            }
            labeledRow("Tool") {
                let machineProviders = providers(draft.machine)
                if machineProviders.isEmpty {
                    Label(noCLIMessage, systemImage: "exclamationmark.triangle")
                        .font(ThemeFont.callout)
                        .foregroundStyle(ThemePalette.secondaryText)
                } else {
                    ThemeSegmentedPicker(
                        "Tool", selection: $draft.provider,
                        segments: machineProviders.map { provider in
                            ThemeSegment(value: Optional(provider), title: Text(provider.rawValue))
                        }
                    )
                    .fixedSize()
                }
            }
            TextEditor(text: $draft.task)
                .font(ThemeFont.callout.monospaced())
                .scrollContentBackground(.hidden)
                .themedTextFieldSurface()
                .accessibilityLabel("Prompt")
            Text("The prompt ends with these sections of the JustSessions guides:")
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
            HostFixAgentGuideSectionToggles(selection: $draft.guideSections)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.errorText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: draft.machine) {
            let machineProviders = providers(draft.machine)
            if draft.provider.map(machineProviders.contains) != true {
                draft.provider = preferredProvider(machineProviders)
            }
        }
    }

    private var machineExplanation: String {
        switch draft.machine {
        case .checkedHost:
            AppLocalization.string("Starts in \(folder(.checkedHost)) on \(host), outside tmux.")
        case .thisMac:
            AppLocalization.string("Starts in your home folder on this Mac, outside tmux, and reaches \(host) with ssh.")
        }
    }

    private var noCLIMessage: String {
        switch draft.machine {
        case .checkedHost: AppLocalization.string("No CLI on \(host) can start; run the agent on this Mac.")
        case .thisMac: AppLocalization.string("No CLI found on this Mac.")
        }
    }

    private func labeledRow<Content: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(ThemeFont.fieldLabel)
                .foregroundStyle(ThemePalette.secondaryText)
                .frame(width: InterfaceScale.points(52), alignment: .leading)
            content()
        }
    }
}
