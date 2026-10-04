import SwiftUI

/// Help as a sheet on a workspace window: what JustSessions does, SSH host setup, and where to send feedback.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("JustSessions Help", systemImage: "questionmark.circle")
                            .font(.title2.weight(.semibold))
                        Text("Find the right AI coding session. Pick up where you left off.")
                            .foregroundStyle(ThemePalette.secondaryText)
                    }

                    HelpFeatureOverview()
                    HelpRemoteHostSection()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }

            ThemeDivider()
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Link("User guide ↗", destination: AppLinks.userGuideURL)
                HelpFeedbackLinks()
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.automatic)
                    .font(.body)
                    .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 600, height: 560)
        .foregroundStyle(ThemePalette.ink)
        .background(ThemePalette.contentSurface)
    }
}
