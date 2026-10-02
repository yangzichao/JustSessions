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

    var isRestoring: Bool { pendingRestoration != nil }
    let entrySeekingRequests = PassthroughSubject<Int, Never>()

    init(conversationID: String, positionStore: TranscriptReadingPositionStore, initialPosition: TranscriptReadingPosition) {
        self.conversationID = conversationID
        self.positionStore = positionStore
        self.pendingRestoration = initialPosition
    }

    func register(_ marker: TranscriptEntryPositionMarkerView, in scrollView: NSScrollView) {
        guard !isStopped else { return }
        entryMarkers.setObject(marker, forKey: NSNumber(value: marker.entryIndex))
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
        }
        scheduleUpdate()
    }

    func stop() {
        isStopped = true
        observations.removeAll()
        entryMarkers.removeAllObjects()
    }

    func unregister(_ marker: TranscriptEntryPositionMarkerView) {
        let key = NSNumber(value: marker.entryIndex)
        if entryMarkers.object(forKey: key) === marker { entryMarkers.removeObject(forKey: key) }
    }

    /// A reader action takes priority over a restoration still waiting for lazy layout.
    func restore(_ position: TranscriptReadingPosition) {
        pendingRestoration = position
        restorationGeometry = nil
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
            self.recordPosition()
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
        if abs(proposedBounds.minY - clipView.bounds.minY) > 0.5 {
            clipView.scroll(to: proposedBounds.origin)
            scrollView.reflectScrolledClipView(clipView)
            scheduleUpdate()
        } else if currentTime - geometryStableSince >= 0.05 {
            self.pendingRestoration = nil
            restorationGeometry = nil
        } else {
            scheduleUpdate()
        }
    }

    private func recordPosition() {
        guard pendingRestoration == nil, !isStopped, let scrollView else { return }
        let clipView = scrollView.contentView
        let visibleBounds = clipView.bounds
        if clipView.documentRect.maxY - visibleBounds.maxY <= 2 {
            positionStore.record(.bottom, for: conversationID)
            return
        }
        let visibleEntries = entryMarkers.dictionaryRepresentation().compactMap { _, view -> (Int, NSRect)? in
            guard let marker = view as? TranscriptEntryPositionMarkerView,
                  marker.enclosingScrollView === scrollView, marker.bounds.height > 0 else { return nil }
            let entryFrame = marker.convert(marker.bounds, to: clipView)
            guard entryFrame.maxY > visibleBounds.minY, entryFrame.minY < visibleBounds.maxY else { return nil }
            return (marker.entryIndex, entryFrame)
        }
        guard let (index, entryFrame) = visibleEntries.min(by: { $0.1.minY < $1.1.minY }) else { return }
        positionStore.record(.entry(index: index, offset: visibleBounds.minY - entryFrame.minY), for: conversationID)
    }
}
