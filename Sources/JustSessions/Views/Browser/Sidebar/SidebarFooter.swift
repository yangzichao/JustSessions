import SwiftUI

/// One line: adding an SSH host, then settings.
struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
            Spacer(minLength: 4)
            SidebarSettingsButton()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
    }
}
