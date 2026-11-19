import SwiftUI

struct SidebarHostRefreshFailureWarning: View {
    let host: SessionHost
    let failureMessage: String
    let onCheckHost: (() -> Void)?

    var body: some View {
        if let onCheckHost {
            Button(action: onCheckHost) { icon }
                .buttonStyle(ThemePressButtonStyle())
                .help(AppLocalization.string("\(failureMessage) Click to check \(host.displayName)."))
                .accessibilityLabel("\(host.displayName) could not be refreshed: \(failureMessage)")
                .accessibilityHint("Checks this host")
        } else {
            icon
                .help(failureMessage)
                .accessibilityLabel("\(host.displayName) could not be refreshed: \(failureMessage)")
        }
    }

    private var icon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(ThemePalette.warning)
            .frame(width: InterfaceScale.points(14), height: InterfaceScale.points(20))
            .contentShape(Rectangle())
    }
}
