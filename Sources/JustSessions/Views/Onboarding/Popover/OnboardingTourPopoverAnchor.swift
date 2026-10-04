import AppKit
import SwiftUI

/// Shows a tour card in a popover whose arrow points at the view this backs. Unlike SwiftUI's popover, it stays open
/// while you click around the window, so you can try what it points at; only the card's buttons close it. It never
/// takes keyboard focus from a terminal. It steps aside while a sheet covers the window, or while the view is
/// scrolled out of sight or out of the window, and comes back after.
struct OnboardingTourPopoverAnchor: NSViewRepresentable {
    /// Nil closes the popover.
    let card: OnboardingTourCard?
    /// The side of the view the popover opens on.
    let edge: Edge

    func makeNSView(context: Context) -> OnboardingTourPopoverAnchorView {
        OnboardingTourPopoverAnchorView()
    }

    func updateNSView(_ view: OnboardingTourPopoverAnchorView, context: Context) {
        view.show(card, on: edge.popoverRectEdge)
    }

    static func dismantleNSView(_ view: OnboardingTourPopoverAnchorView, coordinator: ()) {
        view.show(nil, on: .maxX)
    }
}

final class OnboardingTourPopoverAnchorView: NSView {
    private var card: OnboardingTourCard?
    private var preferredEdge: NSRectEdge = .maxX
    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?
    private var observers: [NSObjectProtocol] = []
    private var isPopoverUpdateScheduled = false

    /// Only anchors the popover; clicks go to the view it backs.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show(_ card: OnboardingTourCard?, on preferredEdge: NSRectEdge) {
        self.card = card
        self.preferredEdge = preferredEdge
        if let card { hostingController?.rootView = Self.rootView(for: card) }
        schedulePopoverUpdate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeSheetsAndScrolling()
        schedulePopoverUpdate()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        schedulePopoverUpdate()
    }

    /// After the SwiftUI update or scroll that asked for it, once the view has its place in the window.
    private func schedulePopoverUpdate() {
        guard !isPopoverUpdateScheduled else { return }
        isPopoverUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.isPopoverUpdateScheduled = false
                self?.updatePopover()
            }
        }
    }

    /// At least half the view shows, so the arrow points at what the card is about rather than past a list's edge.
    private var isInSight: Bool {
        guard let window, window.isVisible, window.attachedSheet == nil, !isHiddenOrHasHiddenAncestor,
              !bounds.isEmpty else { return false }
        guard let clipView = enclosingScrollView?.contentView else { return true }
        // Measured against the scroll view's clip view: `visibleRect` reaches past the bounds of views that don't
        // clip to them, as SwiftUI's hosts don't.
        let shownPart = clipView.bounds.intersection(convert(bounds, to: clipView))
        return !shownPart.isNull && shownPart.height >= bounds.height / 2
    }

    private func updatePopover() {
        guard let card, isInSight else {
            if popover?.isShown == true { popover?.close() }
            return
        }
        let popover = popover ?? makePopover(showing: Self.rootView(for: card))
        if !popover.isShown {
            popover.show(relativeTo: bounds, of: self, preferredEdge: preferredEdge)
        }
    }

    private static func rootView(for card: OnboardingTourCard) -> AnyView {
        AnyView(card.appTheme(from: .shared).appLanguage(from: .shared))
    }

    private func makePopover(showing rootView: AnyView) -> NSPopover {
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = hostingController
        self.hostingController = hostingController
        self.popover = popover
        return popover
    }

    private func observeSheetsAndScrolling() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers = []
        guard let window else { return }
        observers = [
            // The sheet may not be attached yet, so the popover closes now rather than on the next update.
            center.addObserver(forName: NSWindow.willBeginSheetNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.popover?.close() }
            },
            center.addObserver(forName: NSWindow.didEndSheetNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedulePopoverUpdate() }
            },
        ]
        if let clipView = enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedulePopoverUpdate() }
            })
        }
    }
}

private extension Edge {
    /// The popover's side of a view that is not flipped, as this one is not.
    var popoverRectEdge: NSRectEdge {
        switch self {
        case .top: .maxY
        case .bottom: .minY
        case .leading: .minX
        case .trailing: .maxX
        }
    }
}
