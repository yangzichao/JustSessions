import SwiftUI

/// "© 2026 Zichao Yang · MIT License", with the license opening on GitHub.
struct AboutCopyrightLine: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: "\(AboutAppDetails.copyrightNotice) ·")
            Link("MIT License", destination: AppLinks.licenseURL)
                .buttonStyle(ThemePlainButtonStyle())
                .help("Open the license on GitHub")
                .accessibilityIdentifier("about.license")
        }
        .font(.system(size: 11))
        .foregroundStyle(ThemePalette.tertiaryText)
    }
}
