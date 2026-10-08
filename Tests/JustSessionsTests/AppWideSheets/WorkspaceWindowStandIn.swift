import AppKit
import SwiftUI
import Testing
@testable import JustSessions

/// A window on screen that shows Settings and Help the way a workspace window does.
@MainActor
final class WorkspaceWindowStandIn {
    let state = AppWideSheetState()
    let window: NSWindow

    init() {
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 700, height: 640),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AppWideSheetHostingStandIn(state: state))
        window.center()
        window.orderFrontRegardless()
    }

    /// SwiftUI builds the view that registers the window on its first update, after the window is on screen.
    func waitUntilRegistered() async throws {
        try await expectEventually { containsRegistrationView(window.contentView) }
    }

    func close() {
        window.close()
    }

    private func containsRegistrationView(_ view: NSView?) -> Bool {
        guard let view else { return false }
        return view is AppWideSheetWindowRegistrationView || view.subviews.contains { containsRegistrationView($0) }
    }
}

@MainActor
final class AppWideSheetState: ObservableObject {
    @Published var sheet: AppWideSheet?
}

struct AppWideSheetHostingStandIn: View {
    @ObservedObject var state: AppWideSheetState

    var body: some View {
        Color.clear.showsAppWideSheets($state.sheet, onCheckForUpdates: {})
    }
}
