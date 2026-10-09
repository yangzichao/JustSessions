import SwiftUI

/// Under a session's header while a tab in another window runs its CLI. A session runs in one tab across the app's
/// windows, so clicking it here shows its preview, and Show brings that window forward to its tab. Move Here, offered
/// when tmux can keep the CLI running, closes that tab and opens the session here.
struct SessionInAnotherWindowNote: View {
    /// Followed so the note leaves once that tab's CLI ends.
    @ObservedObject var tab: TerminalSession
    let onShow: () -> Void
    let onMoveHere: (() -> Void)?

    var body: some View {
        if !tab.hasExited {
            HStack(spacing: 8) {
                Label("This session is open in another window.", systemImage: "macwindow")
                    .foregroundStyle(ThemePalette.secondaryText)
                Button("Show", action: onShow)
                    .buttonStyle(QuietBorderedButtonStyle())
                if let onMoveHere {
                    Button("Move Here", action: onMoveHere)
                        .buttonStyle(QuietBorderedButtonStyle())
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
