import SwiftUI

/// Adds an SSH host, whose sessions get a heading of their own below this Mac's.
struct SidebarAddRemoteHostButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add SSH host…", systemImage: "plus.circle")
                .lineLimit(1)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .help("List the sessions on another machine you reach with ssh")
    }
}
