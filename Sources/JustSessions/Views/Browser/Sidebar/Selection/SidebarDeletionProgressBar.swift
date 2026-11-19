import SwiftUI

struct SidebarDeletionProgressBar: View {
    @ObservedObject var progress: SessionDeletionProgress
    let onCancel: () -> Void

    @State private var wasStopped = false

    private var sessionBeingDeleted: Int {
        min(progress.completedCount + 1, progress.totalCount)
    }

    private var statusText: LocalizedStringKey {
        progress.isStopping ? "Stopping…" : "Deleting \(sessionBeingDeleted) of \(progress.totalCount)…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(statusText)
                    .font(ThemeFont.callout.weight(.medium))
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Button("Cancel", action: onCancel)
                    .buttonStyle(QuietBorderedButtonStyle())
                    .controlSize(.small)
                    .disabled(progress.isStopping)
                    .help("Stop deleting after the current session; the rest stay listed")
                    .accessibilityLabel("Cancel deletion")
            }
            ProgressView(value: progress.fractionCompleted)
                .progressViewStyle(.linear)
                .controlSize(.small)
                .accessibilityLabel(progress.isStopping ? "Stopping deletion" : "Deleting sessions")
                .accessibilityValue("Session \(sessionBeingDeleted) of \(progress.totalCount)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(ThemePalette.hoverFill)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Deletion progress")
        .onChange(of: progress.isStopping) { _, isStopping in
            guard isStopping else { return }
            wasStopped = true
            AccessibilityNotification.Announcement("Stopping deletion after the current session").post()
        }
        .onDisappear {
            guard progress.totalCount == 0 else { return }
            AccessibilityNotification.Announcement(wasStopped ? "Deletion stopped" : "Deletion finished").post()
        }
    }
}
