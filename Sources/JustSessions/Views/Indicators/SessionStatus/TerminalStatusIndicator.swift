import SwiftUI

struct TerminalStatusIndicator: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        SessionStatusIndicator(status: session.runStatus)
    }
}
