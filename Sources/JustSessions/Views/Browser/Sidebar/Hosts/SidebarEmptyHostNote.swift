import SwiftUI

/// Stands in for a host's projects when it lists none, saying why.
struct SidebarEmptyHostNote: View {
    let message: SidebarEmptyHostMessage

    var body: some View {
        Group {
            if message.isFailure {
                Text(message.text).foregroundStyle(ThemePalette.warning)
            } else {
                Text(message.text).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
    }
}
