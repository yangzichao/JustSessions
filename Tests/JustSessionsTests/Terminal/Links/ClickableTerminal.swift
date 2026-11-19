import AppKit

@testable import JustSessions

@MainActor
final class ClickableTerminal {
    let view: any TabTerminalView
    let window: NSWindow
    private(set) var openedLinks: [String] = []
    private let settings: IsolatedUserDefaults

    init(engine: TerminalEngine) throws {
        _ = NSApplication.shared
        settings = try IsolatedUserDefaults()
        let frame = NSRect(x: 0, y: 0, width: 640, height: 400)
        view = engine.makeTabTerminalView(
            frame: frame,
            appearanceStore: TerminalAppearanceStore(userDefaults: settings.userDefaults),
            themeStore: AppThemeStore(userDefaults: settings.userDefaults)
        )
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        view.onOpenLink = { [weak self] link in self?.openedLinks.append(link) }
    }

    func show(_ output: String) {
        feedOutput(output, to: view)
    }

    func close() {
        window.contentView = nil
        window.close()
        settings.removeSuite()
    }
}
