import SwiftUI

/// Says that feedback becomes a public GitHub issue before anyone starts writing it.
struct FeedbackHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Help improve JustSessions", systemImage: "bubble.left.and.bubble.right")
                .font(.title2.weight(.semibold))
            Text("Report a problem, suggest a feature, or share an idea.")
                .foregroundStyle(ThemePalette.secondaryText)
            Label("Feedback becomes a public GitHub issue and needs a GitHub account. Keep private code, conversations, and credentials out of it.", systemImage: "globe")
                .font(.caption)
                .foregroundStyle(ThemePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
