import SwiftUI

/// What macOS's standard About panel shows, the icon, name, and version, then the app's tagline, where to find it
/// online, and its copyright and license.
struct AboutWindowContent: View {
    private let version = AboutAppDetails.currentVersion

    var body: some View {
        VStack(spacing: 0) {
            AboutAppIconButton()
                .padding(.bottom, 8)
            Text(verbatim: "JustSessions")
                .font(.system(size: 20, weight: .semibold))
            versionLine
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(ThemePalette.secondaryText)
                .textSelection(.enabled)
                .padding(.top, 2)
                .accessibilityIdentifier("about.version")
            // The website's headline, kept in English in every language like the name.
            Text(verbatim: "Nothing extra. Just sessions.")
                .font(.system(size: 12))
                .foregroundStyle(ThemePalette.secondaryText)
                .padding(.top, 10)
            AboutWindowLinks()
                .padding(.top, 14)
            AboutCopyrightLine()
                .padding(.top, 14)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: 320)
        .background(ThemePalette.contentSurface)
    }

    @ViewBuilder private var versionLine: some View {
        if let version {
            Text("Version \(version)")
        } else {
            Text("Development build")
        }
    }
}
