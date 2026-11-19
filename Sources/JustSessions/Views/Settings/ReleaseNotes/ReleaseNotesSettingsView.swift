import SwiftUI

struct ReleaseNotesSettingsView: View {
    let onShowGeneral: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onShowGeneral) {
                    Label("General", systemImage: "chevron.left")
                }
                .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                .accessibilityIdentifier("releaseNotes.backToGeneral")
                Text("Release notes").font(ThemeFont.title)
                Link("Latest release notes ↗", destination: AppLinks.releaseNotesURL)
                    .buttonStyle(ThemePlainButtonStyle(verticalPadding: 2))
                    .accessibilityIdentifier("releaseNotes.website")
            }
            switch AppReleaseHistory.bundled {
            case .success(let releases):
                ForEach(releases) { release in
                    ReleaseNotesEntryView(release: release)
                    if release.id != releases.last?.id { ThemeDivider() }
                }
            case .failure:
                Text("Release history could not be loaded. Read the latest notes on the website.")
                    .foregroundStyle(ThemePalette.secondaryText)
            }
        }
        .foregroundStyle(ThemePalette.ink)
        .textSelection(.enabled)
        .accessibilityIdentifier("settings.releaseNotes")
    }
}
