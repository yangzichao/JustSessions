import AppKit
import SwiftUI

/// Registers the workspace window so menu commands can open Settings or select a page already showing there.
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
        AppWideSheetPresenters.register(window, isShowingSettings: { [weak self] in
            self?.sheet?.wrappedValue != nil
        }) { [weak self] shownSheet in
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
