import AppKit

/// The Dock icon's right-click menu. New Window opens another workspace window, as File > New Window (⌘⇧N) does.
@MainActor
final class WorkspaceDockMenu: NSObject {
    static let shared = WorkspaceDockMenu()

    /// AppKit cannot open a SwiftUI window, so each workspace window hands over SwiftUI's action as it appears. The
    /// action still opens one after every window has closed.
    var openWorkspaceWindow: (() -> Void)?

    /// macOS asks for the menu each time it shows it, so the title follows the language chosen in Settings.
    func makeMenu(language: AppInterfaceLanguage = AppLanguageStore.shared.language) -> NSMenu {
        let menu = NSMenu()
        let newWindowItem = NSMenuItem(
            title: AppLocalization.string("New Window", language: language),
            action: #selector(openNewWorkspaceWindow),
            keyEquivalent: ""
        )
        newWindowItem.target = self
        menu.addItem(newWindowItem)
        return menu
    }

    @objc private func openNewWorkspaceWindow() {
        openWorkspaceWindow?()
    }
}
