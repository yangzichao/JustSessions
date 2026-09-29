import SwiftUI

/// A session whose CLI still runs in tmux on its host, with no tab open here.
struct TmuxRunningIndicator: View {
    let host: SessionHost

    var body: some View {
        Image(systemName: "circle.dashed")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(ThemePalette.live)
            .help("Still running in tmux on \(host.nameInSentence); resume to reattach")
            .accessibilityLabel("Running on \(host.nameInSentence)")
    }
}
