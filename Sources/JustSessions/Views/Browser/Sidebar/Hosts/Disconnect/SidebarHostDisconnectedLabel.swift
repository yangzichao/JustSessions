import SwiftUI

struct SidebarHostDisconnectedLabel: View {
    let host: SessionHost

    var body: some View {
        Text("Disconnected")
            .font(ThemeFont.caption)
            .foregroundStyle(ThemePalette.tertiaryText)
            .fixedSize()
            .accessibilityLabel(Text("\(host.displayName) is disconnected"))
    }
}
