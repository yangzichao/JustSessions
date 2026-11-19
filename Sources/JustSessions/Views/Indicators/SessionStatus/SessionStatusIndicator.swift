import SwiftUI

struct SessionStatusIndicator: View {
    let status: SessionRunStatus
    var description: String?

    static func descriptionOfDetachedCLI(_ status: SessionRunStatus, on host: SessionHost) -> String {
        "\(status.summary) · in tmux on \(host.nameInSentence), no tab open; click to reattach"
    }

    var body: some View {
        glyph
            .frame(width: InterfaceScale.points(10), height: InterfaceScale.points(10))
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
                .font(ThemeFont.glyph(.control, weight: .semibold))
                .foregroundStyle(ThemePalette.warning)
        case .finishedUnseen:
            Image(systemName: "circle.fill")
                .font(ThemeFont.glyph(.statusMark, weight: .semibold))
                .foregroundStyle(ThemePalette.unseenTurn)
        case .running(.idle), .running(nil):
            Image(systemName: "circle.fill")
                .font(ThemeFont.glyph(.statusDot, weight: .semibold))
                .foregroundStyle(ThemePalette.live)
        case .ended:
            Image(systemName: "circle")
                .font(ThemeFont.glyph(.statusDot, weight: .semibold))
                .foregroundStyle(ThemePalette.secondaryText)
        case .waitingToBeShown:
            Image(systemName: "circle.dotted")
                .font(ThemeFont.glyph(.statusMark, weight: .semibold))
                .foregroundStyle(ThemePalette.secondaryText)
        }
    }
}
