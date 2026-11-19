import AppKit

@MainActor
final class SheetClickOutsideMonitor {
    private var eventMonitor: Any?

    init(window: NSWindow, onClickOutside: @escaping @MainActor () -> Bool) {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak window] event in
            let isTaken = MainActor.assumeIsolated {
                guard let window, Self.isClickOutsideSheet(event, in: window) else { return false }
                return onClickOutside()
            }
            return isTaken ? nil : event
        }
    }

    static func isClickOutsideSheet(_ event: NSEvent, in window: NSWindow) -> Bool {
        event.window === window && window.attachedSheet != nil
    }

    func stop() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }
}
