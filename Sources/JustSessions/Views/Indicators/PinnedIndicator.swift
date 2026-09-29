import SwiftUI

/// Small pin glyph shown beside pinned projects and sessions.
struct PinnedIndicator: View {
    var size: CGFloat = 8

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.tertiary)
            .help("Pinned")
            .accessibilityLabel("Pinned")
    }
}
