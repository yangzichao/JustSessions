import SwiftUI

/// A tab's terminal. The tab names the session and its group names the project, so the terminal starts right under
/// the tab bar; a bar above it appears only once the CLI has ended.
struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    let isActive: Bool
    /// Shown for a remote tab whose connection ended.
    let onReconnect: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if session.hasExited {
                TerminalEndedBar(exitCode: session.exitCode, onReconnect: onReconnect)
                ThemeDivider()
            }
            EmbeddedTerminalView(session: session, isActive: isActive)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
