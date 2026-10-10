import AppKit
import SwiftUI

/// The About JustSessions window. It replaces macOS's standard panel, whose icon cannot be clicked and which has no
/// room for links. There is one; asking again brings it forward.
@MainActor
final class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // Like macOS's About panel, it stays out of the Window menu's list.
        window.isExcludedFromWindowsMenu = true
        let hostingController = NSHostingController(
            rootView: AboutWindowContent().appTheme(from: .shared).appLanguage(from: .shared)
        )
        hostingController.sizingOptions = .preferredContentSize
        window.contentViewController = hostingController
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show(language: AppInterfaceLanguage = AppLanguageStore.shared.language) {
        guard let window else { return }
        // The title bar hides it; VoiceOver and Mission Control still read it.
        window.title = AppLocalization.string("About JustSessions", language: language)
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }
}
