import SwiftUI

struct TerminalAppearancePreview: NSViewRepresentable {
    let engine: TerminalEngine
    let appearanceStore: TerminalAppearanceStore
    let themeStore: AppThemeStore

    private static let powerlineBranchGlyphDrawnByTheBundledNerdFontSymbols = "\u{E0A0}"

    private static let sampleText = [
        " JustSessions",
        " \(powerlineBranchGlyphDrawnByTheBundledNerdFontSymbols) main $ run project",
        " \u{1B}[32mReady\u{1B}[0m to work",
        " \u{1B}[33mWarning\u{1B}[0m · review changes",
        " \u{1B}[31mError\u{1B}[0m · sample message",
        " \u{1B}[34mBlue\u{1B}[0m  \u{1B}[35mPurple\u{1B}[0m  \u{1B}[36mCyan\u{1B}[0m",
    ].joined(separator: "\r\n")

    func makeNSView(context: Context) -> NSView {
        let frame = NSRect(x: 0, y: 0, width: 490, height: 220)
        switch engine {
        case .ghostty:
            let terminalView = GhosttyTabTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore)
            terminalView.inMemorySession.receive(Self.sampleText)
            return terminalView
        case .swiftTerm:
            let terminalView = SelectableTerminalView(frame: frame, appearanceStore: appearanceStore, themeStore: themeStore)
            terminalView.feed(text: Self.sampleText)
            return terminalView
        }
    }

    func updateNSView(_ terminalView: NSView, context: Context) {}
}
