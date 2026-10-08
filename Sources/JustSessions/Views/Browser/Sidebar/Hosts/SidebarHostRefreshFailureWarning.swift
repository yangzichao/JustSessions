import SwiftUI

/// The warning after a host's name while its last refresh has failed; its tooltip says why. It sits apart from the
/// refresh status, which an SSH host's ⋯ takes the place of under the pointer, so the pointer can rest on it.
struct SidebarHostRefreshFailureWarning: View {
    let host: SessionHost
    let failureMessage: String

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(ThemePalette.warning)
            .frame(width: 14, height: 20)
            .contentShape(Rectangle())
            .help(failureMessage)
            .accessibilityLabel("\(host.displayName) could not be refreshed: \(failureMessage)")
    }
}
