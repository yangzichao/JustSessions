import SwiftUI

/// A tab's terminal. The tab names the session and its group names the project, so the terminal starts right under
/// the tab bar; a bar above it appears only once the CLI has ended.
struct TerminalWorkspaceView: View {
    @ObservedObject var session: TerminalSession
    /// The terminal is on screen, full width or as either half of a split.
    let isShown: Bool
    /// The tab is selected, so its terminal gets the keyboard.
    let isActive: Bool
    /// Shown for a remote tab whose connection ended.
    let onReconnect: (() -> Void)?
    /// Called when a click lands on the terminal, before it takes the keyboard.
    let onFocus: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if session.hasExited {
                TerminalEndedBar(exitCode: session.exitCode, onReconnect: onReconnect)
                ThemeDivider()
            }
            EmbeddedTerminalView(session: session, isShown: isShown, isActive: isActive, onFocus: onFocus)
                .id(session.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
