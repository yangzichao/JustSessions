import AppKit
import SwiftUI

extension View {
    func dismissesOnClickOutside(isPresented: Binding<Bool>) -> some View {
        background(ClickOutsideDismissal(isPresented: isPresented))
    }

    func dismissesOnClickOutside<Item: Sendable>(item: Binding<Item?>) -> some View {
        dismissesOnClickOutside(isPresented: Binding(isPresenting: item))
    }
}

private struct ClickOutsideDismissal: NSViewRepresentable {
    @Binding var isPresented: Bool

    func makeNSView(context: Context) -> ClickOutsideDismissalView {
        ClickOutsideDismissalView()
    }

    func updateNSView(_ view: ClickOutsideDismissalView, context: Context) {
        view.isPresented = $isPresented
    }

    static func dismantleNSView(_ view: ClickOutsideDismissalView, coordinator: ()) {
        view.stopMonitoring()
    }
}

private final class ClickOutsideDismissalView: NSView {
    var isPresented: Binding<Bool>?
    private var clickOutsideMonitor: SheetClickOutsideMonitor?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard let window else { return }
        clickOutsideMonitor = SheetClickOutsideMonitor(window: window) { [weak self] in
            guard let isPresented = self?.isPresented, isPresented.wrappedValue else { return false }
            isPresented.wrappedValue = false
            return true
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func stopMonitoring() {
        clickOutsideMonitor?.stop()
        clickOutsideMonitor = nil
    }
}
