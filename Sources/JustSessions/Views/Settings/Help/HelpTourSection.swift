import SwiftUI

/// The top of Help: the tour, which also shows every tip again, the user guide, and whether the sidebar shows a
/// random tip.
struct HelpTourSection: View {
    @Environment(\.startOnboardingTour) private var startOnboardingTour
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                "The tour points at the main controls in the window. Afterwards, tips show again the first time you use each part, such as tabs or split view."
            )
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Button("Take the tour") {
                    // The tour points at the window, so Settings closes first; its tips show once the sheet is gone.
                    dismiss()
                    startOnboardingTour()
                }
                .buttonStyle(QuietBorderedButtonStyle())
                .accessibilityIdentifier("help.take-the-tour")
                Link("User guide ↗", destination: AppLinks.userGuideURL)
                    .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                    .accessibilityIdentifier("help.user-guide")
            }
            ThemeDivider()
            HelpRandomTipsToggle()
        }
        .font(ThemeFont.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemePalette.raisedSurface, in: RoundedRectangle(.panel))
        .overlay {
            RoundedRectangle(.panel).stroke(ThemePalette.hairline)
        }
    }
}
