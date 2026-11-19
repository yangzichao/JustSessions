import SwiftUI

struct SessionInAnotherWindowNote: View {
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
            .font(ThemeFont.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
