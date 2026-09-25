import SwiftUI

/// A green dot while a tab's CLI runs and a hollow one after it exits, on the tab and on its sidebar row.
struct TerminalStatusIndicator: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        Image(systemName: session.hasExited ? "circle" : "circle.fill")
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(session.hasExited ? Color.secondary : ThemePalette.live)
            .accessibilityLabel(session.hasExited ? "Ended" : "Running")
    }
}
