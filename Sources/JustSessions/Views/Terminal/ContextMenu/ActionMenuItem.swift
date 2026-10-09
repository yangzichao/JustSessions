import AppKit

/// A menu item that runs a closure, for a menu built in AppKit whose actions belong to the views around it.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, systemImage: String? = nil, isEnabled: Bool = true, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(performHandler), keyEquivalent: "")
        target = self
        image = systemImage.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        self.isEnabled = isEnabled
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("ActionMenuItem is created in code") }

    @objc private func performHandler() {
        handler()
    }
}
