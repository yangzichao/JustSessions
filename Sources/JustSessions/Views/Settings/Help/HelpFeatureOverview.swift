import SwiftUI

/// Help in Settings: what each part of the window does, in the order a session is found, read, resumed, and kept
/// running, then organizing sessions and notifications.
struct HelpFeatureOverview: View {
    @Environment(\.locale) private var locale

    private var providerList: String {
        let formatter = ListFormatter()
        formatter.locale = locale
        let providers = ConversationProvider.allCases.map(\.rawValue)
        return formatter.string(from: providers) ?? providers.joined(separator: ", ")
    }

    var body: some View {
        HelpSection(title: "How it works") {
            VStack(alignment: .leading, spacing: 12) {
                HelpFeatureRow(title: "Find a session", systemImage: "magnifyingglass",
                               detail: "The sidebar lists sessions from \(providerList) by host and project. Search matches project names and paths, session titles, and IDs.")
                HelpFeatureRow(title: "Read a session", systemImage: "book",
                               detail: "Click a session to read its conversation; no CLI starts. **Open in new window** gives it a window of its own.")
                HelpFeatureRow(title: "Resume or branch", systemImage: "play",
                               detail: "**Resume**, or a double-click, continues the conversation in its CLI and original folder. **Branch**, where the CLI supports it, starts a new session from a copy and leaves the original as it was.")
                HelpFeatureRow(title: "Tabs and split view", systemImage: "rectangle.split.2x1",
                               detail: "**⌘N** starts a session in any installed CLI, or a plain terminal. Tabs group by project, and **Open tabs** in the sidebar lists them all. Right-click a tab to show two side by side.")
                HelpFeatureRow(title: "Keep running", systemImage: "arrow.triangle.2.circlepath",
                               detail: "Close a tab with **Keep running**, or quit the app, and the CLI carries on in tmux. Click its session to return. A plain terminal ends with its tab.")
                HelpFeatureRow(title: "Organize", systemImage: "pin",
                               detail: "Right-click a session to rename, pin, export, or delete it, and a project to rename, pin, or archive it. ⌘-click or ⇧-click selects several.")
                HelpFeatureRow(title: "Notifications", systemImage: "bell",
                               detail: "Claude Code and Codex on this Mac notify you when they finish a turn or need your input, unless you are looking at their tab. Choose which in General.")
            }
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
        }
    }
}
