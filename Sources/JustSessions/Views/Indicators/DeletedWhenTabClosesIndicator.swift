import SwiftUI

struct DeletedWhenTabClosesIndicator: View {
    var size: ThemeGlyphSize = .statusMark

    var body: some View {
        Image(systemName: "hourglass")
            .font(ThemeFont.glyph(size, weight: .semibold))
            .foregroundStyle(ThemePalette.tertiaryText)
            .help("Deleted when its tab closes")
            .accessibilityLabel("Deleted when its tab closes")
    }
}
