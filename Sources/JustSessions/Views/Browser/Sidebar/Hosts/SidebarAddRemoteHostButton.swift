import SwiftUI

/// The last row of the sidebar list: adds an SSH host, whose sessions get a heading of their own below this Mac's.
struct SidebarAddRemoteHostButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16)
                Text("Add SSH host…")
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .contentShape(Rectangle())
            .sidebarRowHighlight(isSelected: false)
        }
        .buttonStyle(.plain)
        .help("List the sessions on another machine you reach with ssh")
        .padding(.horizontal, 8)
    }
}
