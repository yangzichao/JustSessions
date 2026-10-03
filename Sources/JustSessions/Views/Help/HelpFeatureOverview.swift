import SwiftUI

/// What sets JustSessions apart, in the order a session is found, read, resumed, kept running, and reached remotely.
struct HelpFeatureOverview: View {
    @Environment(\.locale) private var locale

    private var providerList: String {
        let formatter = ListFormatter()
        formatter.locale = locale
        let providers = ConversationProvider.allCases.map(\.rawValue)
        return formatter.string(from: providers) ?? providers.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What makes it different").font(.headline)

            HelpFeatureRow(title: "All your CLIs in one place", systemImage: "square.stack.3d.up",
                           detail: "\(providerList), by host and project. It reads the history they already save: no import, no account.")
            HelpFeatureRow(title: "Read without resuming", systemImage: "book",
                           detail: "Preview a session, or open it in its own reading window. Nothing runs until you resume.")
            HelpFeatureRow(title: "Resume where you left off", systemImage: "terminal",
                           detail: "Continue in the original CLI and project folder, inside the app. **Branch** to try another approach.")
            HelpFeatureRow(title: "Keep it running", systemImage: "arrow.triangle.2.circlepath",
                           detail: "Close a tab with **Keep running**, or quit the app. Built-in tmux keeps the CLI going; click the session to reattach.")
            HelpFeatureRow(title: "Work on other machines", systemImage: "network",
                           detail: "Resume sessions on SSH hosts. The code and CLI stay on that machine.")
        }
    }
}

private struct HelpFeatureRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).foregroundStyle(ThemePalette.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}
