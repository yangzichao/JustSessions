import SwiftUI

extension View {
    /// Lets the Dock menu's New Window open a workspace window through this view's `openWindow`.
    func opensWindowsFromDockMenu() -> some View {
        modifier(DockMenuWindowOpening())
    }
}

private struct DockMenuWindowOpening: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            WorkspaceDockMenu.shared.openWorkspaceWindow = { openWindow(id: "workspace") }
        }
    }
}
