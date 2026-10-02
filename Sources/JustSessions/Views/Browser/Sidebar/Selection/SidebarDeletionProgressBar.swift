import SwiftUI

/// Shown at the bottom of the sidebar while several sessions are being deleted, in place of the session
/// selection's action bar.
struct SidebarDeletionProgressBar: View {
    @ObservedObject var progress: SessionDeletionProgress
    let onCancel: () -> Void

    /// Cancel was chosen while this bar was shown, so its disappearance means the deletion stopped early.
    @State private var wasStopped = false

    /// Names the session being deleted, so the first one reads "1 of 140" rather than "0 of 140".
    private var sessionBeingDeleted: Int {
        min(progress.completedCount + 1, progress.totalCount)
    }

    private var statusText: String {
        progress.isStopping ? "Stopping…" : "Deleting \(sessionBeingDeleted) of \(progress.totalCount)…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                // No Escape shortcut: Escape belongs to the terminal and to clearing the sidebar selection.
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
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
            // The sidebar can also be hidden while the deletion runs; only an ended deletion has been reset.
            guard progress.totalCount == 0 else { return }
            AccessibilityNotification.Announcement(wasStopped ? "Deletion stopped" : "Deletion finished").post()
        }
    }
}
