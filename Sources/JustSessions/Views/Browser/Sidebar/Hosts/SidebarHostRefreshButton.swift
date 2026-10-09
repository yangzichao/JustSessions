import SwiftUI

/// A host's own refresh action and progress; another host's refresh never changes this control.
struct SidebarHostRefreshButton: View {
    let host: SessionHost
    let refreshStatus: HostRefreshStatus?
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if refreshStatus == .refreshing {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel(refreshingAccessibilityLabel)
            } else {
                Button(action: action) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: 16, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: 4))
                .disabled(isDisabled)
                .help(refreshAccessibilityLabel)
                .accessibilityLabel(refreshAccessibilityLabel)
            }
        }
        .frame(width: 16, height: 20)
        .accessibilityIdentifier(host.sshDestination.map { "sidebar.refreshHost.ssh.\($0)" } ?? "sidebar.refreshHost.thisMac")
    }

    private var refreshAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Refresh sessions on this Mac" : "Refresh sessions on \(host.displayName)"
    }

    private var refreshingAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Refreshing this Mac" : "Refreshing \(host.displayName)"
    }
}
