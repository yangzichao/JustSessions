import SwiftUI

struct PinnedIndicator: View {
    var size: ThemeGlyphSize = .statusMark

    var body: some View {
        Image(systemName: "pin.fill")
            .font(ThemeFont.glyph(size, weight: .semibold))
            .foregroundStyle(ThemePalette.tertiaryText)
            .help("Pinned")
            .accessibilityLabel("Pinned")
    }
}
