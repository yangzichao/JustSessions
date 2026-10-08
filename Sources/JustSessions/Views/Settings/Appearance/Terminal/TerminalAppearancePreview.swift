import SwiftUI

/// Uses the same renderer and live appearance subscription as session tabs, without starting a process.
struct TerminalAppearancePreview: NSViewRepresentable {
    let appearanceStore: TerminalAppearanceStore
    let themeStore: AppThemeStore

    func makeNSView(context: Context) -> SelectableTerminalView {
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 490, height: 220),
            appearanceStore: appearanceStore,
            themeStore: themeStore
        )
        terminalView.feed(text: [
            " JustSessions",
            // A Powerline branch icon, as shell prompts show, which the bundled Nerd Font symbols draw with any font.
            " \u{E0A0} main $ run project",
            " \u{1B}[32mReady\u{1B}[0m to work",
            " \u{1B}[33mWarning\u{1B}[0m · review changes",
            " \u{1B}[31mError\u{1B}[0m · sample message",
            " \u{1B}[34mBlue\u{1B}[0m  \u{1B}[35mPurple\u{1B}[0m  \u{1B}[36mCyan\u{1B}[0m",
        ].joined(separator: "\r\n"))
        return terminalView
    }

    func updateNSView(_ terminalView: SelectableTerminalView, context: Context) {}
}
