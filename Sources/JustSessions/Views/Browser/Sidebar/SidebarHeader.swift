import SwiftUI

/// App mark and name with the refresh control, kept to one short line so the session list gets the height.
struct SidebarHeader: View {
    @ObservedObject var store: ConversationStore

    var body: some View {
        HStack(spacing: 8) {
            JustSessionsMark()
                .frame(width: 21, height: 18)
            Text("JustSessions")
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 8)
            refreshControl
                .frame(width: 20, height: 20)
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .frame(height: 46)
    }

    @ViewBuilder
    private var refreshControl: some View {
        if store.isLoading {
            ProgressView().controlSize(.small)
        } else {
            Button { store.refreshIncludingRemoteHosts() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isDeletingSessions)
            .help("Refresh sessions")
            .accessibilityLabel("Refresh sessions")
        }
    }
}
