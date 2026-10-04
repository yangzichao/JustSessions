import SwiftUI

struct SelectedProjectsContextMenu: View {
    let selectedCount: Int
    let onRemove: () -> Void

    var body: some View {
        Text("\(selectedCount) projects selected")
        Button("Archive \(selectedCount) projects", systemImage: "archivebox", action: onRemove)
    }
}
