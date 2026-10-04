import AppKit
import SwiftUI

/// Registers the window it sits in with `AppWideSheetPresenters` as a workspace window that shows Settings and Help
/// by setting `sheet`.
struct AppWideSheetWindowRegistration: NSViewRepresentable {
    @Binding var sheet: AppWideSheet?

    func makeNSView(context: Context) -> AppWideSheetWindowRegistrationView {
        AppWideSheetWindowRegistrationView()
    }

    func updateNSView(_ view: AppWideSheetWindowRegistrationView, context: Context) {
        view.sheet = $sheet
    }

    static func dismantleNSView(_ view: AppWideSheetWindowRegistrationView, coordinator: ()) {
        view.unregister()
    }
}

final class AppWideSheetWindowRegistrationView: NSView {
    var sheet: Binding<AppWideSheet?>?
    private weak var registeredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unregister()
        guard let window else { return }
        registeredWindow = window
        AppWideSheetPresenters.register(window) { [weak self] shownSheet in
            self?.sheet?.wrappedValue = shownSheet
        }
    }

    /// Only registers; clicks go to the views it sits behind.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func unregister() {
        if let registeredWindow { AppWideSheetPresenters.unregister(registeredWindow) }
        registeredWindow = nil
    }
}
