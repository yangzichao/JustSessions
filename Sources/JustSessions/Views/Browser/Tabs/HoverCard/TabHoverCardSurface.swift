import SwiftUI

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
                    .themeShadow(.floating)
            }
            .overlay { shape.strokeBorder(ThemePalette.hairline) }
    }
}
