import SwiftUI

/// Refreshes every host, and turns into a spinner while any host refreshes.
struct SidebarRefreshButton: View {
    @ObservedObject var store: ConversationStore

    var body: some View {
        Group {
            if store.isRefreshingAnyHost {
                ProgressView().controlSize(.small)
            } else {
                Button { store.refreshAllHosts() } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(store.isDeletingSessions)
                .help("Refresh sessions")
                .accessibilityLabel("Refresh sessions")
            }
        }
        .frame(width: 24, height: 24)
    }
}
