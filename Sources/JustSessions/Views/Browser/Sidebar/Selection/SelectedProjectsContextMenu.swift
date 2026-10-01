import SwiftUI

struct SelectedProjectsContextMenu: View {
    let selectedCount: Int
    let onRemove: () -> Void
    let onClear: () -> Void

    var body: some View {
        Text("\(selectedCount) projects selected")
        Button("Remove \(selectedCount) projects from sidebar", systemImage: "sidebar.left", action: onRemove)
        Divider()
        Button("Clear selection", action: onClear)
    }
}
