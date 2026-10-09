import SwiftUI

extension View {
    /// Lets the Dock menu's New Window, and a tab dragged out of its window, open a workspace window through this
    /// view's `openWindow`.
    func handsOverWindowOpening() -> some View {
        modifier(WindowOpeningHandOver())
    }
}

private struct WindowOpeningHandOver: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            WorkspaceDockMenu.shared.openWorkspaceWindow = { openWindow(id: "workspace") }
            WorkspaceWindowRegistry.shared.openWorkspaceWindow = { openWindow(id: "workspace") }
        }
    }
}
