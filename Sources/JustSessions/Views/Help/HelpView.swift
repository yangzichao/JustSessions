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
                        Text("Browse, read, and resume your coding sessions.")
                            .foregroundStyle(ThemePalette.secondaryText)
                    }

                    HelpRemoteHostSection()
                    HelpFeatureOverview()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }

            ThemeDivider()
            HStack {
                Link("User guide ↗", destination: AppLinks.userGuideURL)
                Spacer()
                Link("Report an issue ↗", destination: AppLinks.githubIssuesURL)
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
