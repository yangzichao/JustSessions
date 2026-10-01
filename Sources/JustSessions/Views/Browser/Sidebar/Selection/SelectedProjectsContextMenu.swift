import SwiftUI

struct SelectedProjectsContextMenu: View {
    let selectedCount: Int
    let onRemove: () -> Void

    var body: some View {
        Text("\(selectedCount) projects selected")
        Button("Remove \(selectedCount) projects from sidebar", systemImage: "sidebar.left", action: onRemove)
    }
}
