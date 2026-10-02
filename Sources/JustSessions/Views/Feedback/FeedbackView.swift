import AppKit
import SwiftUI

struct FeedbackView: View {
    static let windowID = "feedback"

    @Environment(\.openURL) private var openURL
    @State private var draft: FeedbackDraft
    @State private var statusMessage = ""

    init(initialDraft: FeedbackDraft = FeedbackDraft()) {
        _draft = State(initialValue: initialDraft)
    }

    private var versionInformation: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development build"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "JustSessions: \(appVersion) (\(buildNumber))\nmacOS: \(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FeedbackHeader()

            FeedbackForm(draft: $draft, versionInformation: versionInformation)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("feedback.status")
            }

            HStack {
                Link("Browse feedback ↗", destination: AppLinks.githubIssuesURL)
                    .buttonStyle(.plain)
                    .foregroundStyle(ThemePalette.ink)
                Spacer()
                Button("Copy feedback") { copyReport() }
                    .buttonStyle(QuietBorderedButtonStyle())
                    .disabled(!draft.canContinue)
                Button("Continue on GitHub…", action: continueOnGitHub)
                    .buttonStyle(ThemeProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.canContinue)
                    .accessibilityIdentifier("feedback.continue")
            }
        }
        .padding(24)
        .frame(width: 560)
        .foregroundStyle(ThemePalette.ink)
        .background(ThemePalette.contentSurface)
        .onChange(of: draft.title) { _, _ in statusMessage = "" }
        .onChange(of: draft.details) { _, _ in statusMessage = "" }
        .onChange(of: draft.kind) { _, _ in statusMessage = "" }
        .onChange(of: draft.includesVersionInformation) { _, _ in statusMessage = "" }
    }

    @discardableResult
    private func copyReport() -> Bool {
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setString(draft.copyableReport(versionInformation: versionInformation), forType: .string)
        statusMessage = copied ? "Feedback copied. You can paste it into a GitHub issue." : "Could not copy feedback. Try again."
        return copied
    }

    private func continueOnGitHub() {
        guard draft.canContinue else { return }
        let issueURL: URL
        if let prefilledURL = draft.prefilledIssueURL(versionInformation: versionInformation) {
            issueURL = prefilledURL
            statusMessage = "Review your feedback on GitHub, then submit it there."
        } else {
            guard copyReport() else { return }
            issueURL = draft.titleOnlyIssueURL
            statusMessage = "Your long report was copied. Paste it into the issue body on GitHub, then submit it there."
        }
        openURL(issueURL) { accepted in
            if !accepted { statusMessage = "Could not open the browser. Copy your feedback and open a new issue at github.com/yangzichao/JustSessions/issues." }
        }
    }
}
