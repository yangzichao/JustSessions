import AppKit
import SwiftUI

/// Tells the window registry which window shows the store, so a session opened in another window can bring this one
/// forward to its tab. See `WorkspaceWindowRegistry`.
struct WorkspaceWindowRegistration: NSViewRepresentable {
    let store: ConversationStore

    func makeNSView(context: Context) -> WorkspaceWindowRegistrationView {
        WorkspaceWindowRegistrationView(store: store)
    }

    func updateNSView(_ view: WorkspaceWindowRegistrationView, context: Context) {}
}

final class WorkspaceWindowRegistrationView: NSView {
    private weak var store: ConversationStore?

    init(store: ConversationStore) {
        self.store = store
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("WorkspaceWindowRegistrationView is created in code") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let store else { return }
        store.windowRegistry.setWindow(window, for: store)
    }

    /// Only registers; clicks go to the views it sits behind.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
