import SwiftUI

/// A visible support entry remains available in every sidebar state.
struct SidebarFeedbackButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: FeedbackView.windowID)
        } label: {
            Label("Feedback", systemImage: "bubble.left")
                .labelStyle(.iconOnly)
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .help("Report a problem or suggest a feature")
        .accessibilityLabel("Feedback")
        .accessibilityIdentifier("sidebar.feedback")
    }
}
