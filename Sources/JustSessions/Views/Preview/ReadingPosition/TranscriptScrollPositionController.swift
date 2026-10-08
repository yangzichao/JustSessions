import AppKit
import Combine

/// SwiftUI finds the saved entry in a lazy stack; AppKit restores the offset within that entry after layout.
@MainActor
final class TranscriptScrollPositionController {
    private struct RestorationGeometry: Equatable {
        let documentRect: NSRect
        let viewportBounds: NSRect
        let entryFrame: NSRect?
    }

    private let conversationID: String
    private let positionStore: TranscriptReadingPositionStore
    private var pendingRestoration: TranscriptReadingPosition?
    weak var scrollView: NSScrollView?
    let entryMarkers = NSMapTable<NSNumber, NSView>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var observations: Set<AnyCancellable> = []
    private var hasScheduledUpdate = false
    private var isStopped = false
    private var restorationGeometry: RestorationGeometry?
    private var geometryStableSince: TimeInterval = 0
    /// Whether the pending restoration has put the reader in place at least once; see `handOverToScrolling()`.
    private var hasAppliedRestoration = false
    private var restoresDuringLayout = false
    private var scrollWheelMonitor: Any?

    var isRestoring: Bool { pendingRestoration != nil }
    /// How long the layout stays put before a restoration ends. Tests lengthen it to act while one is pending.
    var settlingDuration: TimeInterval = 0.05
    var recordedPosition: TranscriptReadingPosition? { positionStore.position(for: conversationID) }
    var tracksTranscriptBottom = true
    let entrySeekingRequests = PassthroughSubject<Int, Never>()
    let viewportUpdates = PassthroughSubject<TranscriptPagingViewport, Never>()

    var pagingViewport: TranscriptPagingViewport? {
        guard let clipView = scrollView?.contentView else { return nil }
        return TranscriptPagingViewport(document: clipView.documentRect, visible: clipView.bounds)
    }

    /// Where the row of the entry at `index` starts in the document, measured as `pagingViewport` is. Nil while the
    /// row is not laid out.
    func documentMinY(ofEntryAt index: Int) -> CGFloat? {
        guard let scrollView, let marker = entryMarkers.object(forKey: NSNumber(value: index)),
              marker.enclosingScrollView === scrollView else { return nil }
        return marker.convert(marker.bounds, to: scrollView.contentView).minY
    }

    init(conversationID: String, positionStore: TranscriptReadingPositionStore, initialPosition: TranscriptReadingPosition) {
        self.conversationID = conversationID
        self.positionStore = positionStore
        self.pendingRestoration = initialPosition
    }

    func register(_ marker: TranscriptEntryPositionMarkerView, in scrollView: NSScrollView) {
        guard !isStopped else { return }
        entryMarkers.setObject(marker, forKey: NSNumber(value: marker.entryIndex))
        if restoresDuringLayout, self.scrollView === scrollView, pendingRestoration?.entryIndex == marker.entryIndex {
            restoresDuringLayout = false
            restorePositionIfNeeded()
        }
        if self.scrollView !== scrollView {
            self.scrollView = scrollView
            observations.removeAll()
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.publisher(for: NSView.boundsDidChangeNotification, object: scrollView.contentView)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.recordPosition()
                        self?.scheduleUpdate()
                    }
                }
                .store(in: &observations)
            NotificationCenter.default.publisher(for: NSScrollView.willStartLiveScrollNotification, object: scrollView)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.pendingRestoration = nil }
                }
                .store(in: &observations)
            monitorScrollWheel()
        }
        scheduleUpdate()
    }

    func stop() {
        isStopped = true
        observations.removeAll()
        entryMarkers.removeAllObjects()
        if let scrollWheelMonitor { NSEvent.removeMonitor(scrollWheelMonitor) }
        scrollWheelMonitor = nil
    }

    private func monitorScrollWheel() {
        if let scrollWheelMonitor { NSEvent.removeMonitor(scrollWheelMonitor) }
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let scrollView = self.scrollView, event.window === scrollView.window,
                      scrollView.bounds.contains(scrollView.convert(event.locationInWindow, from: nil)) else { return }
                self.handOverToScrolling()
            }
            return event
        }
    }

    /// Scrolling over the transcript ends a restoration once it has put the reader in place, and carries on from there.
    /// A mouse wheel posts no live-scroll notification, and neither does momentum after a page loads, so the restoration
    /// otherwise pulled the view back on every update until the wheel stopped, and the reader bounced. Before that, the
    /// restoration still applies, or the reader would lose its place to the page that just loaded above it.
    func handOverToScrolling() {
        guard pendingRestoration != nil, hasAppliedRestoration else { return }
        pendingRestoration = nil
        restorationGeometry = nil
    }

    func unregister(_ marker: TranscriptEntryPositionMarkerView) {
        let key = NSNumber(value: marker.entryIndex)
        if entryMarkers.object(forKey: key) === marker { entryMarkers.removeObject(forKey: key) }
    }

    /// A reader action takes priority over a restoration still waiting for lazy layout.
    /// With `duringNextLayout`, the entry's row is on screen already, as when a page loads above or below it. Its marker
    /// lays out after the rows around it move, in the same pass, before the window draws, so the restoration applies
    /// there and the reader never sees the content in between. Otherwise it waits for SwiftUI to lay out the row.
    func restore(_ position: TranscriptReadingPosition, duringNextLayout: Bool = false) {
        pendingRestoration = position
        restorationGeometry = nil
        hasAppliedRestoration = false
        restoresDuringLayout = duringNextLayout && position.entryIndex != nil
        if restoresDuringLayout, let index = position.entryIndex {
            entryMarkers.object(forKey: NSNumber(value: index))?.needsLayout = true
        }
        scheduleUpdate()
    }

    /// Rewrapping, such as after a text size or reading width change, resizes every entry; return to the entry being
    /// read. The lazy stack may have dropped that entry's row, so SwiftUI first brings it back into view.
    func restoreRecordedPosition() {
        guard pendingRestoration == nil, let position = positionStore.position(for: conversationID) else { return }
        restore(position)
        if let index = position.entryIndex { entrySeekingRequests.send(index) }
    }

    private func scheduleUpdate() {
        guard !hasScheduledUpdate, !isStopped else { return }
        hasScheduledUpdate = true
        // Let SwiftUI commit lazy row measurements before applying a native offset.
        let delay = pendingRestoration == nil ? 0.0 : 0.016
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.hasScheduledUpdate = false
            self.restorePositionIfNeeded()
            let hasReadingPosition = self.recordPosition()
            // Recheck after restoration and lazy layout, even if the first visible message did not change.
            if hasReadingPosition, let viewport = self.pagingViewport { self.viewportUpdates.send(viewport) }
        }
    }

    private func restorePositionIfNeeded() {
        guard let pendingRestoration, let scrollView, let documentView = scrollView.documentView,
              scrollView.contentView.bounds.height > 0, documentView.bounds.height > 0 else { return }
        let clipView = scrollView.contentView
        var proposedBounds = clipView.bounds
        var restoredEntryFrame: NSRect?
        switch pendingRestoration {
        case .bottom:
            proposedBounds.origin.y = clipView.documentRect.maxY - proposedBounds.height
        case .entry(let index, let offset):
            guard let marker = entryMarkers.object(forKey: NSNumber(value: index)),
                  marker.enclosingScrollView === scrollView, marker.bounds.height > 0 else { return }
            let entryFrame = marker.convert(marker.bounds, to: clipView)
            // A hidden lazy row still has an estimated frame. Ask SwiftUI to reveal it before measuring.
            guard !marker.isHiddenOrHasHiddenAncestor, abs(entryFrame.midX - clipView.documentRect.midX) < 1 else {
                entrySeekingRequests.send(index)
                scheduleUpdate()
                return
            }
            restoredEntryFrame = entryFrame
            proposedBounds.origin.y = entryFrame.minY + min(offset, max(0, entryFrame.height - 1))
        }
        let geometry = RestorationGeometry(documentRect: clipView.documentRect, viewportBounds: clipView.bounds, entryFrame: restoredEntryFrame)
        let currentTime = ProcessInfo.processInfo.systemUptime
        if geometry != restorationGeometry {
            restorationGeometry = geometry
            geometryStableSince = currentTime
        }
        proposedBounds = clipView.constrainBoundsRect(proposedBounds)
        defer { hasAppliedRestoration = true }
        if abs(proposedBounds.minY - clipView.bounds.minY) > 0.5 {
            clipView.scroll(to: proposedBounds.origin)
            scrollView.reflectScrolledClipView(clipView)
            scheduleUpdate()
        } else if currentTime - geometryStableSince >= settlingDuration {
            self.pendingRestoration = nil
            restorationGeometry = nil
        } else {
            scheduleUpdate()
        }
    }

    @discardableResult
    private func recordPosition() -> Bool {
        guard pendingRestoration == nil, !isStopped, let scrollView else { return false }
        let clipView = scrollView.contentView
        let visibleBounds = clipView.bounds
        if tracksTranscriptBottom, clipView.documentRect.maxY - visibleBounds.maxY <= 2 {
            positionStore.record(.bottom, for: conversationID)
            return true
        }
        let visibleEntries = entryMarkers.dictionaryRepresentation().compactMap { _, view -> (Int, NSRect)? in
            guard let marker = view as? TranscriptEntryPositionMarkerView,
                  marker.enclosingScrollView === scrollView, marker.bounds.height > 0 else { return nil }
            let entryFrame = marker.convert(marker.bounds, to: clipView)
            guard entryFrame.maxY > visibleBounds.minY, entryFrame.minY < visibleBounds.maxY else { return nil }
            return (marker.entryIndex, entryFrame)
        }
        guard let (index, entryFrame) = visibleEntries.min(by: { $0.1.minY < $1.1.minY }) else { return false }
        positionStore.record(.entry(index: index, offset: visibleBounds.minY - entryFrame.minY), for: conversationID)
        return true
    }
}
