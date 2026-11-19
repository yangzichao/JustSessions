import AppKit
import SwiftUI

struct TerminalFindShortcuts: NSViewRepresentable {
    let selectedTabFind: TerminalFindState?
    let onFind: () -> Void

    func makeNSView(context: Context) -> ShortcutView { ShortcutView() }

    func updateNSView(_ view: ShortcutView, context: Context) {
        view.selectedTabFind = selectedTabFind
        view.onFind = onFind
    }

    static func dismantleNSView(_ view: ShortcutView, coordinator: ()) { view.stop() }

    final class ShortcutView: NSView {
        var selectedTabFind: TerminalFindState?
        var onFind: (() -> Void)?
        private var monitor: Any?

        override init(frame: NSRect) {
            super.init(frame: frame)
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let isHandled = MainActor.assumeIsolated { self.handle(event) == nil }
                return isHandled ? nil : event
            }
        }

        required init?(coder: NSCoder) { nil }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        func handle(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, let findState = selectedTabFind else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let key = event.charactersIgnoringModifiers?.lowercased()
            if modifiers == .command, key == "f" {
                onFind?()
                return nil
            }
            guard findState.isPresented else { return event }
            if key == "g", modifiers == .command || modifiers == [.command, .shift] {
                findState.move(modifiers.contains(.shift) ? .towardNewer : .towardOlder)
                return nil
            }
            guard findState.isFieldFocused, let fieldEditor = window.firstResponder as? NSTextView,
                !fieldEditor.hasMarkedText()
            else { return event }
            if event.keyCode == 36 || event.keyCode == 76, modifiers.isEmpty || modifiers == .shift {
                findState.move(modifiers.contains(.shift) ? .towardNewer : .towardOlder)
                return nil
            }
            if event.keyCode == 53, modifiers.isEmpty {
                findState.close()
                return nil
            }
            return event
        }
    }
}
