import AppKit
import SwiftUI

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
        store.windowRegistry.setWindowHandingOverItsFirstWindow(window, for: store)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
