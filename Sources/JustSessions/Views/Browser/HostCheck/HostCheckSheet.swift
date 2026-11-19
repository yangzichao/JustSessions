import AppKit
import SwiftUI

struct HostCheckSheet: View {
    let store: ConversationStore
    let presentedState: HostCheckSheetState
    @Environment(\.dismiss) private var dismiss
    @State private var hasCopiedReport = false
    @State private var fixAgentDraft: HostFixAgentDraft?
    @State private var isStartingFixAgent = false
    @State private var fixAgentStartError: String?

    private static let findingsHeight: CGFloat = 420

    private var state: HostCheckSheetState {
        store.hostCheck ?? presentedState
    }

    var body: some View {
        ThemeSheetLayout(
            title: fixAgentDraft == nil ? Text("Check \(state.host)") : Text("Fix \(state.host) with an agent"),
            intro: fixAgentDraft == nil
                ? Text(
                    "Runs on \(state.host) what JustSessions runs there. When a command below fails the same way in your own Terminal, the problem is on \(state.host)."
                )
                : Text(
                    "Starts a CLI whose first message is this report, so it can find out why and fix it with you. It's told to ask you before it ends sessions or changes the host's setup."
                ),
            width: ThemeSheetMetrics.wideWidth
        ) {
            Group {
                if let report = state.report, let draftBinding = Binding($fixAgentDraft) {
                    HostFixAgentForm(
                        draft: draftBinding,
                        host: report.host,
                        providers: { store.hostFixAgentProviders(on: $0, report: report) },
                        preferredProvider: { store.preferredHostFixAgentProvider(among: $0) },
                        folder: { store.hostFixAgentFolder(on: $0, for: state, report: report) },
                        errorMessage: fixAgentStartError
                    )
                } else if let report = state.report {
                    reportView(report)
                } else {
                    HostCheckProgressView(
                        host: state.host,
                        step: state.step,
                        stepStartedAt: state.stepStartedAt,
                        checksTabFolder: state.session != nil
                    )
                }
            }
            .frame(height: Self.findingsHeight)
        } footer: {
            if let fixAgentDraft {
                fixAgentFooter(fixAgentDraft)
            } else {
                reportFooter
            }
        }
        .onChange(of: state.runID) {
            hasCopiedReport = false
            fixAgentDraft = nil
        }
    }

    @ViewBuilder private var reportFooter: some View {
        Button(hasCopiedReport ? "Copied" : "Copy report", systemImage: hasCopiedReport ? "checkmark" : "doc.on.doc") {
            guard let report = state.report else { return }
            NSPasteboard.general.clearContents()
            hasCopiedReport = NSPasteboard.general.setString(report.plainText, forType: .string)
        }
        .disabled(state.isChecking)
        .help("Copy the report as text, for an issue or for whoever runs the host")
        Button("Check again", systemImage: "arrow.clockwise") { store.checkShownHostAgain() }
            .disabled(state.isChecking)
        Spacer()
        if let report = state.report, report.hasSomethingToFix {
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Fix with agent…", systemImage: "wrench.and.screwdriver") {
                fixAgentStartError = nil
                fixAgentDraft = store.hostFixAgentDraft(for: state, report: report)
            }
            .buttonStyle(ThemeProminentButtonStyle())
            .keyboardShortcut(.defaultAction)
            .help("Start a CLI that reads this report and fixes the problem with you")
        } else {
            Button("Done") { dismiss() }
                .buttonStyle(ThemeProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder private func fixAgentFooter(_ draft: HostFixAgentDraft) -> some View {
        if isStartingFixAgent && draft.machine == .checkedHost {
            ProgressView().controlSize(.small)
            Text("Finding the folder on \(state.host)…")
                .font(ThemeFont.callout)
                .foregroundStyle(ThemePalette.secondaryText)
        }
        Spacer()
        Button("Back") { fixAgentDraft = nil }
            .keyboardShortcut(.cancelAction)
            .disabled(isStartingFixAgent)
        Button(startButtonTitle(draft.provider), action: startFixAgent)
            .buttonStyle(ProviderProminentButtonStyle(tint: (draft.provider.map(NewSessionKind.cli) ?? .plainTerminal).emphasisTintColor))
            .keyboardShortcut(.defaultAction)
            .disabled(
                draft.provider == nil || isStartingFixAgent
                    || draft.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func startButtonTitle(_ provider: ConversationProvider?) -> LocalizedStringKey {
        guard let provider else { return "Start" }
        return "Start \(provider.rawValue)"
    }

    private func startFixAgent() {
        guard let draft = fixAgentDraft, let report = state.report else { return }
        isStartingFixAgent = true
        fixAgentStartError = nil
        let state = state
        Task {
            do {
                try await store.startHostFixAgent(draft, for: state, report: report)
            } catch {
                fixAgentStartError = error.localizedDescription
            }
            isStartingFixAgent = false
        }
    }

    private func reportView(_ report: HostCheckReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HostCheckStatusIcon(status: overallStatus(of: report))
                Text(verbatim: verdict(of: report))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(ThemeFont.body.weight(.medium))
            ViewThatFits(in: .vertical) {
                findingsList(report)
                ScrollView { findingsList(report) }
            }
            .background(ThemePalette.raisedSurface, in: RoundedRectangle(.card))
            .overlay(RoundedRectangle(.card).stroke(ThemePalette.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(.card))
            .layoutPriority(1)
            Text("Checked \(report.checkedAt.formatted(.relative(presentation: .named))) · This Mac: \(report.thisMacSummary)")
                .font(ThemeFont.detail)
                .foregroundStyle(ThemePalette.tertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func findingsList(_ report: HostCheckReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(report.findingsMostImportantFirst) { finding in
                HostCheckFindingRow(finding: finding, host: report.host)
                if finding.id != report.findingsMostImportantFirst.last?.id {
                    ThemeDivider()
                }
            }
            if let endedTabScreen = report.endedTabScreen {
                ThemeDivider()
                HostCheckEndedTabScreenRow(screenText: endedTabScreen)
            }
        }
    }

    private func overallStatus(of report: HostCheckReport) -> HostCheckFinding.Status {
        if report.problemCount > 0 { return .problem }
        if report.warningCount > 0 { return .warning }
        return .passed
    }

    private func verdict(of report: HostCheckReport) -> String {
        if report.problemCount > 0 {
            return AppLocalization.string("Found something on \(report.host) that keeps sessions from working; see the problems below.")
        }
        if report.warningCount > 0 {
            return AppLocalization.string("Sessions on \(report.host) can work, but see the warnings below.")
        }
        return AppLocalization.string("Found nothing on \(report.host) that keeps sessions from working.")
    }
}
