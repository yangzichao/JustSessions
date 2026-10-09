import SwiftUI

/// Small pin glyph shown beside a pinned session's title. A pinned project shows a pin in place of its folder.
struct PinnedIndicator: View {
    var size: CGFloat = 8

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ThemePalette.tertiaryText)
            .help("Pinned")
            .accessibilityLabel("Pinned")
    }
}
