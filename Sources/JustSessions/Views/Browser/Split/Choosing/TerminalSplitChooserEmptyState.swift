import SwiftUI

struct TerminalSplitChooserEmptyState: View {
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
