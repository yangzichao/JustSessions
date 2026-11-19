import SwiftUI

extension View {
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
