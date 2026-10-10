import SwiftUI

/// The hover card's raised surface: outlined in the theme's hairline and lifted off the terminal under it.
struct TabHoverCardSurface<Content: View>: View {
    @ViewBuilder let content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TabHoverCardMetrics.cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: TabHoverCardMetrics.width, alignment: .leading)
            .background {
                shape
                    .fill(ThemePalette.raisedSurface)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            }
            .overlay { shape.strokeBorder(ThemePalette.hairline) }
    }
}
