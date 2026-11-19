import SwiftUI

struct AllTabGroupsCollapsing {
    let canCollapseAll: Bool
    let canExpandAll: Bool
    let collapseAll: () -> Void
    let expandAll: () -> Void
}

struct AllTabGroupsCollapseMenuItems: View {
    let allGroups: AllTabGroupsCollapsing

    var body: some View {
        Button("Collapse all groups", systemImage: "chevron.left.2", action: allGroups.collapseAll)
            .disabled(!allGroups.canCollapseAll)
        Button("Expand all groups", systemImage: "chevron.right.2", action: allGroups.expandAll)
            .disabled(!allGroups.canExpandAll)
    }
}
