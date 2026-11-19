import SwiftUI

struct SidebarHostRefreshButton: View {
    let host: SessionHost
    let refreshStatus: HostRefreshStatus?
    let isDisabled: Bool
    let connectsFirst: Bool
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
                        .font(ThemeFont.glyph(.control, weight: .medium))
                        .foregroundStyle(ThemePalette.secondaryText)
                        .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(20))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ThemePlainButtonStyle(cornerRadius: .small))
                .disabled(isDisabled)
                .help(refreshAccessibilityLabel)
                .accessibilityLabel(refreshAccessibilityLabel)
            }
        }
        .frame(width: InterfaceScale.points(16), height: InterfaceScale.points(20))
        .accessibilityIdentifier(host.sshDestination.map { "sidebar.refreshHost.ssh.\($0)" } ?? "sidebar.refreshHost.thisMac")
    }

    private var refreshAccessibilityLabel: LocalizedStringKey {
        if connectsFirst { return "Connect and refresh sessions on \(host.displayName)" }
        return host == .thisMac ? "Refresh sessions on this Mac" : "Refresh sessions on \(host.displayName)"
    }

    private var refreshingAccessibilityLabel: LocalizedStringKey {
        host == .thisMac ? "Refreshing this Mac" : "Refreshing \(host.displayName)"
    }
}
