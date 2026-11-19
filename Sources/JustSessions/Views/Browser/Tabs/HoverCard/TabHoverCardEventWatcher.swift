import AppKit
import SwiftUI

struct TabHoverCardEventWatcher: NSViewRepresentable {
    let controller: TabHoverCardController

    func makeNSView(context: Context) -> TabHoverCardEventWatcherView {
        TabHoverCardEventWatcherView()
    }

    func updateNSView(_ view: TabHoverCardEventWatcherView, context: Context) {
        view.controller = controller
    }

    static func dismantleNSView(_ view: TabHoverCardEventWatcherView, coordinator: ()) {
        view.stopWatching()
    }
}

final class TabHoverCardEventWatcherView: NSView {
    weak var controller: TabHoverCardController?
    private var eventMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopWatching()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.report(event)
            return event
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.reset() }
        }
    }

    func stopWatching() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        if let resignActiveObserver { NotificationCenter.default.removeObserver(resignActiveObserver) }
        resignActiveObserver = nil
    }

    private func report(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: controller?.mouseDown()
        case .leftMouseUp: controller?.mouseUp()
        default: controller?.dismiss()
        }
    }
}
