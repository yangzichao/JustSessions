import SwiftUI

struct TabGroupsBackgroundMenuItems: View {
    let onNewSession: () -> Void
    let allGroups: AllTabGroupsCollapsing

    var body: some View {
        Button("New session…", systemImage: "plus", action: onNewSession)
        Divider()
        AllTabGroupsCollapseMenuItems(allGroups: allGroups)
    }
}
