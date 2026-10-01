import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Control-Tab can be consumed by AppKit focus traversal or a CLI's keyboard protocol before menu commands.
/// Handle only those two aliases, and only in this workspace's window while no sheet or close dialog is open.
struct WorkspaceTabCycleShortcuts: NSViewRepresentable {
    let isEnabled: Bool
    let onSelectAdjacentTab: (_ movingForward: Bool) -> Void

    func makeNSView(context: Context) -> WorkspaceTabCycleShortcutView {
        WorkspaceTabCycleShortcutView()
    }

    func updateNSView(_ view: WorkspaceTabCycleShortcutView, context: Context) {
        view.isEnabled = isEnabled
        view.onSelectAdjacentTab = onSelectAdjacentTab
    }

    static func dismantleNSView(_ view: WorkspaceTabCycleShortcutView, coordinator: ()) {
        view.stopMonitoring()
    }
}

final class WorkspaceTabCycleShortcutView: NSView {
    var isEnabled = false
    var onSelectAdjacentTab: ((_ movingForward: Bool) -> Void)?
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isEnabled, let window, event.window === window,
                  NSApp.keyWindow === window, window.attachedSheet == nil,
                  let movingForward = Self.cycleDirection(for: event) else { return event }
            onSelectAdjacentTab?(movingForward)
            return nil
        }
    }

    func stopMonitoring() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
    }

    /// Ignore Caps Lock and Fn, which do not change the intended shortcut.
    static func cycleDirection(for event: NSEvent) -> Bool? {
        guard event.type == .keyDown, event.keyCode == UInt16(kVK_Tab) else { return nil }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        switch modifiers {
        case .control: return true
        case [.control, .shift]: return false
        default: return nil
        }
    }
}
