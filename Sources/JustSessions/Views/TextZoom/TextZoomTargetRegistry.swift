import AppKit

/// What View → Zoom In, Zoom Out, and Actual Size size, read from AppKit's key and main windows when one is chosen.
/// A SwiftUI focused value can be missing when the menu command runs, as while no scene has focus, and the shortcut
/// would then do nothing.
@MainActor
final class TextZoomTargetRegistry {
    static let shared = TextZoomTargetRegistry()

    private let reporters = NSHashTable<TextZoomTargetReportingView>.weakObjects()

    func register(_ reporter: TextZoomTargetReportingView) {
        reporters.add(reporter)
    }

    /// The key window's target, or else the main window's, which stays the workspace window while one of its sheets
    /// or popovers is key. A Read window shows a conversation.
    func target(
        keyWindow: NSWindow?,
        mainWindow: NSWindow?,
        isReadingWindow: (NSWindow) -> Bool
    ) -> TextZoomTarget? {
        for window in [keyWindow, mainWindow].compactMap({ $0 }) {
            if isReadingWindow(window) { return .conversation }
            if let reporter = reporters.allObjects.first(where: { $0.window === window }) { return reporter.target }
        }
        return nil
    }
}
