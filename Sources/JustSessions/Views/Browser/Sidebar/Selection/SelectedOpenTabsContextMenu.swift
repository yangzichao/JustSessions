import SwiftUI

struct SelectedOpenTabsContextMenu: View {
    let selectedTabCount: Int
    let onClose: () -> Void

    var body: some View {
        Button("Close \(selectedTabCount) tabs…", systemImage: "xmark", role: .destructive, action: onClose)
    }
}
