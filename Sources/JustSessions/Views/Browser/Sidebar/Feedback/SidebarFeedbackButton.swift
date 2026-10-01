import SwiftUI

/// A visible support entry remains available in every sidebar state.
struct SidebarFeedbackButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: FeedbackView.windowID)
        } label: {
            Label("Feedback", systemImage: "bubble.left")
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .help("Report a problem or suggest a feature")
        .accessibilityIdentifier("sidebar.feedback")
    }
}
