import SwiftUI

struct HelpWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("JustSessions Help", systemImage: "questionmark.circle") {
            openWindow(id: HelpView.windowID)
        }
    }
}
