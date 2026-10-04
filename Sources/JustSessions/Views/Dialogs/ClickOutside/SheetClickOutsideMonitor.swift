import AppKit

/// Watches a window for clicks while a sheet covers it, which AppKit would only answer with a beep, and hands each to
/// `onClickOutside` so the sheet can close as Cancel would. That includes the title bar, where the tab bar sits. Clicks
/// in the sheet itself and in other windows pass.
@MainActor
final class SheetClickOutsideMonitor {
    private var eventMonitor: Any?

    /// `onClickOutside` returns whether it took the click. A click it takes goes no further.
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
