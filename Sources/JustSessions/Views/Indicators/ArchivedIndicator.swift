import SwiftUI

struct ArchivedIndicator: View {
    var size: ThemeGlyphSize = .statusMark

    var body: some View {
        Image(systemName: "archivebox")
            .font(ThemeFont.glyph(size, weight: .semibold))
            .foregroundStyle(ThemePalette.tertiaryText)
            .help("Archived")
            .accessibilityLabel("Archived")
    }
}
