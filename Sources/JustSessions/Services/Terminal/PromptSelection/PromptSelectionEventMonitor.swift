import AppKit

/// The app's keys, clicks, and menu items while a prompt is selected: a local event monitor, and an observer of the
/// actions menu items send, which hears an Edit menu item chosen with the pointer. Both go away with this object, so a
/// terminal closed while its prompt is selected leaves neither behind.
final class PromptSelectionEventMonitor {
    private let monitor: Any?
    private let menuActionObserver: NSObjectProtocol

    @MainActor
    init(
        matching mask: NSEvent.EventTypeMask,
        handleEvent: @escaping @MainActor (NSEvent) -> Bool,
        handleMenuAction: @escaping @MainActor (String) -> Void
    ) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            let goesOn = MainActor.assumeIsolated { handleEvent(event) }
            return goesOn ? event : nil
        }
        menuActionObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.willSendActionNotification, object: nil, queue: .main
        ) { notification in
            guard let action = (notification.userInfo?["MenuItem"] as? NSMenuItem)?.action else { return }
            let actionName = NSStringFromSelector(action)
            MainActor.assumeIsolated { handleMenuAction(actionName) }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.removeObserver(menuActionObserver)
    }
}
