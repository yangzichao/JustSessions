import SwiftUI

struct SidebarAddRemoteHostButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add SSH host…", systemImage: "plus")
                .lineLimit(1)
                .frame(height: InterfaceScale.points(30))
                .contentShape(Rectangle())
        }
        .help("List the sessions on another machine you reach with ssh")
    }
}
