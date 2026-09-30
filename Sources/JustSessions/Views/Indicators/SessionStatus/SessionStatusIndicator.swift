import SwiftUI

/// What a session's CLI is doing, as one small glyph: a turning arc while it works, an amber mark while it needs
/// your input, a green dot while it runs otherwise, and a hollow circle once it ended in a tab still open.
struct SessionStatusIndicator: View {
    let status: SessionRunStatus
    /// The tooltip and accessibility label; the status's own summary unless given.
    var description: String?

    /// For a CLI running in tmux with no tab open, which clicking the session reattaches to.
    static func descriptionOfDetachedCLI(_ status: SessionRunStatus, on host: SessionHost) -> String {
        "\(status.summary) · in tmux on \(host.nameInSentence), no tab open; click to reattach"
    }

    var body: some View {
        glyph
            .frame(width: 10, height: 10)
            .help(description ?? status.summary)
            .accessibilityElement()
            .accessibilityLabel(description ?? status.summary)
    }

    @ViewBuilder
    private var glyph: some View {
        switch status {
        case .running(.working):
            WorkingSpinner()
        case .running(.needsInput):
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ThemePalette.warning)
        case .running(.idle), .running(nil):
            Image(systemName: "circle.fill")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(ThemePalette.live)
        case .ended:
            Image(systemName: "circle")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
