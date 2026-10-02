import SwiftUI

/// The status of a tab's CLI, on the tab and on its sidebar row.
struct TerminalStatusIndicator: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        SessionStatusIndicator(status: session.runStatus)
    }
}
