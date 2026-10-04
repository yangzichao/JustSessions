import SwiftUI

/// One line: adding an SSH host, then help and settings as icons.
struct SidebarFooter: View {
    let onAddRemoteHost: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            SidebarAddRemoteHostButton(action: onAddRemoteHost)
            Spacer(minLength: 4)
            SidebarHelpButton()
            SidebarSettingsButton()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
    }
}
