import SwiftUI

/// A remote session whose CLI still runs in tmux on its host, with no tab open here.
struct RemoteTmuxRunningIndicator: View {
    let host: String

    var body: some View {
        Image(systemName: "circle.dashed")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(Color.green)
            .help("Still running on \(host) in tmux; resume to reattach")
            .accessibilityLabel("Running on \(host)")
    }
}
