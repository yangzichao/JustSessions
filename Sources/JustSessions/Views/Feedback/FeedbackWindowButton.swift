import SwiftUI

struct FeedbackWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Send Feedback…", systemImage: "bubble.left") {
            openWindow(id: FeedbackView.windowID)
        }
    }
}
