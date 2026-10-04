import SwiftUI

/// Help in Settings: the main flow, in the order a session is found, read, resumed, and kept running.
struct HelpFeatureOverview: View {
    @Environment(\.locale) private var locale
    @Environment(\.startOnboardingTour) private var startOnboardingTour
    @Environment(\.dismiss) private var dismiss

    private var providerList: String {
        let formatter = ListFormatter()
        formatter.locale = locale
        let providers = ConversationProvider.allCases.map(\.rawValue)
        return formatter.string(from: providers) ?? providers.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("How it works").font(.headline)
                Spacer(minLength: 12)
                Button("Take the tour") {
                    // The tour points at the window, so Settings closes first; its tips show once the sheet is gone.
                    dismiss()
                    startOnboardingTour()
                }
                .buttonStyle(QuietBorderedButtonStyle())
                .controlSize(.small)
                .accessibilityIdentifier("help.take-the-tour")
            }

            HelpFeatureRow(title: "Find", systemImage: "square.stack.3d.up",
                           detail: "Sessions from \(providerList), grouped by host and project.")
            HelpFeatureRow(title: "Read", systemImage: "book",
                           detail: "Click a session to read it. Nothing runs.")
            HelpFeatureRow(title: "Resume", systemImage: "terminal",
                           detail: "**Resume** continues in the original CLI and folder. **Branch** tries another approach.")
            HelpFeatureRow(title: "Keep running", systemImage: "arrow.triangle.2.circlepath",
                           detail: "Close a tab with **Keep running**, or quit. The CLI keeps going; click the session to return.")
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
