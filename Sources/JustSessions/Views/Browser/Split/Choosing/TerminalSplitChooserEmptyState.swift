import SwiftUI

/// A split chooser with no tab to list, which Chrome fills with a new tab: New Session… starts one in the chooser's
/// place.
struct TerminalSplitChooserEmptyState: View {
    /// How the split it would make lays out its views, which its icon shows.
    let orientation: TerminalSplit.Orientation
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: orientation.systemImage)
                .font(ThemeFont.glyph(.emptyState))
                .foregroundStyle(ThemePalette.secondaryText)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Complete your split view")
                    .font(ThemeFont.heading)
                    .foregroundStyle(ThemePalette.ink)
                Text("Start a new session to show it here.")
                    .font(ThemeFont.callout)
                    .foregroundStyle(ThemePalette.secondaryText)
            }
            .multilineTextAlignment(.center)
            Button("New Session…", action: onNewSession)
                .buttonStyle(QuietBorderedButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
