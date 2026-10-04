import SwiftUI

struct HelpView: View {
    static let windowID = "help"

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
            HStack(alignment: .firstTextBaseline) {
                Link("User guide ↗", destination: AppLinks.userGuideURL)
                Spacer()
                HelpFeedbackLinks()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 480, minHeight: 560)
        .foregroundStyle(ThemePalette.ink)
        .background(ThemePalette.contentSurface)
    }
}
