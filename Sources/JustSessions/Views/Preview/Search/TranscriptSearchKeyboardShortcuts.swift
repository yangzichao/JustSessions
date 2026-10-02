import AppKit
import SwiftUI

/// Window-local shortcuts work even when the sidebar has focus. A hidden preview leaves CLI keys alone.
struct TranscriptSearchKeyboardShortcuts: NSViewRepresentable {
    let searchState: TranscriptSearchState
    let isActive: Bool

    func makeNSView(context: Context) -> ShortcutView { ShortcutView() }

    func updateNSView(_ view: ShortcutView, context: Context) {
        view.searchState = searchState
        view.isActive = isActive
    }

    static func dismantleNSView(_ view: ShortcutView, coordinator: ()) { view.stop() }

    final class ShortcutView: NSView {
        var searchState: TranscriptSearchState?
        var isActive = false
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
            guard isActive, let window, event.window === window, let searchState else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let key = event.charactersIgnoringModifiers?.lowercased()
            if modifiers == .command, key == "f" {
                searchState.show()
                return nil
            }
            guard searchState.isPresented else { return event }
            if (event.keyCode == 36 || event.keyCode == 76), modifiers.isEmpty || modifiers == .shift,
               searchState.isFieldFocused, let fieldEditor = window.firstResponder as? NSTextView, !fieldEditor.hasMarkedText() {
                searchState.move(forward: !modifiers.contains(.shift))
                return nil
            }
            if key == "g", modifiers == .command || modifiers == [.command, .shift] {
                searchState.move(forward: !modifiers.contains(.shift))
                return nil
            }
            if event.keyCode == 53, modifiers.isEmpty {
                searchState.close()
                return nil
            }
            return event
        }
    }
}
