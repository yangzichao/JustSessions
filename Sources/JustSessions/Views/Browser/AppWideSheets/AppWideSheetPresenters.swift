import AppKit

/// The open workspace windows and how each shows Settings or Help, so the app menu shows them on the frontmost
/// workspace window, also while a reading window has focus.
@MainActor
enum AppWideSheetPresenters {
    private struct Registration {
        weak var window: NSWindow?
        let show: (AppWideSheet) -> Void
    }

    private static var registrations: [Registration] = []
    /// Asked for while no workspace window was open, so the window opened for it shows it as it appears.
    private static var sheetForNewWorkspaceWindow: AppWideSheet?

    static func register(_ window: NSWindow, show: @escaping (AppWideSheet) -> Void) {
        unregister(window)
        registrations.append(Registration(window: window, show: show))
    }

    static func unregister(_ window: NSWindow) {
        registrations.removeAll { $0.window == nil || $0.window === window }
    }

    /// Shows `sheet` on the frontmost workspace window, or on one `openWorkspaceWindow` opens when none is open. A
    /// window that already shows a sheet, alert, or dialog only comes forward.
    static func show(_ sheet: AppWideSheet, openWorkspaceWindow: () -> Void) {
        registrations.removeAll { $0.window == nil }
        let frontmostRegistration = NSApp.orderedWindows.lazy
            .filter(\.isVisible)
            .compactMap { window in registrations.first { $0.window === window } }
            .first
        // A closed window can stay registered until it is released; only a minimized one comes back.
        let minimizedRegistration = registrations.first { $0.window?.isMiniaturized == true }
        guard let registration = frontmostRegistration ?? minimizedRegistration, let window = registration.window else {
            sheetForNewWorkspaceWindow = sheet
            openWorkspaceWindow()
            return
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        if window.attachedSheet == nil { registration.show(sheet) }
    }

    /// The sheet asked for while no workspace window was open, handed out once.
    static func takeSheetForNewWorkspaceWindow() -> AppWideSheet? {
        defer { sheetForNewWorkspaceWindow = nil }
        return sheetForNewWorkspaceWindow
    }
}
