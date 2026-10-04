import SwiftUI

/// App maintenance at the bottom of General: the installed version, updates, and the website.
struct SoftwareUpdateSettingsSection: View {
    let onCheckForUpdates: () -> Void

    private var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Software updates")
                        .font(.subheadline.weight(.medium))
                    Text("Version \(installedVersion)")
                        .font(.caption)
                        .foregroundStyle(ThemePalette.secondaryText)
                }
                Spacer(minLength: 12)
                Button("Check for updates", action: onCheckForUpdates)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .accessibilityIdentifier("settings.checkForUpdates")
            }
            Link("JustSessions website ↗", destination: AppLinks.websiteURL)
                .help("Open the JustSessions website")
        }
    }
}
