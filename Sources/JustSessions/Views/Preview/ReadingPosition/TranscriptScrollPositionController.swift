import AppKit
import Combine

@MainActor
final class TranscriptScrollPositionController {
    private struct RestorationGeometry: Equatable {
        let documentRect: NSRect
        let viewportBounds: NSRect
        let entryFrame: NSRect?
    }

    private static let delayForSwiftUIToCommitRowMeasurements: TimeInterval = 0.016

    private let conversationID: String
    private let positionStore: TranscriptReadingPositionStore
    private var pendingRestoration: TranscriptReadingPosition?
    weak var scrollView: NSScrollView?
    private weak var geometryView: TranscriptEntryGeometryView?
    private var entryGeometries: [TranscriptEntryGeometry] = []
    private var geometryIndexByEntry: [Int: Int] = [:]
    private var observations: Set<AnyCancellable> = []
    private var hasScheduledUpdate = false
    private var isStopped = false
    private var restorationGeometry: RestorationGeometry?
    private var geometryStableSince: TimeInterval = 0
    private var hasAppliedRestoration = false
    private var restoresDuringLayout = false
    private var scrollWheelMonitor: Any?
    private(set) var pointerLocation: CGPoint?
    private(set) var pointerMovedSinceSeek = false
    private var pointerTracking: TranscriptPointerTracking?

    var isRestoring: Bool { pendingRestoration != nil }
    var settlingDuration: TimeInterval = 0.05
    var recordedPosition: TranscriptReadingPosition? { positionStore.position(for: conversationID) }
    var tracksTranscriptBottom = true
    let entrySeekingRequests = PassthroughSubject<Int, Never>()
    let viewportUpdates = PassthroughSubject<TranscriptPagingViewport, Never>()
    let readingUpdates = PassthroughSubject<Void, Never>()
    private var hasScheduledReadingUpdate = false

    var pagingViewport: TranscriptPagingViewport? {
        guard let clipView = scrollView?.contentView else { return nil }
        return TranscriptPagingViewport(document: clipView.documentRect, visible: clipView.bounds)
    }

    func documentMinY(ofEntryAt index: Int) -> CGFloat? {
        entryFrameInClipView(at: index)?.minY
    }

    init(conversationID: String, positionStore: TranscriptReadingPositionStore, initialPosition: TranscriptReadingPosition) {
        self.conversationID = conversationID
        self.positionStore = positionStore
        self.pendingRestoration = initialPosition
    }

    func updateEntryGeometries(_ geometries: [TranscriptEntryGeometry]) {
        entryGeometries = geometries
        geometryIndexByEntry = Dictionary(uniqueKeysWithValues: geometries.indices.map { (geometries[$0].entryIndex, $0) })
        geometryDidLayout()
        scheduleReadingUpdate()
    }

    /// Not during the layout pass itself, which mustn't change what views read.
    private func scheduleReadingUpdate() {
        guard !hasScheduledReadingUpdate, !isStopped else { return }
        hasScheduledReadingUpdate = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasScheduledReadingUpdate = false
            if !self.isStopped { self.readingUpdates.send() }
        }
    }

    func entryFrameInStack(at index: Int) -> CGRect? {
        guard let geometryIndex = geometryIndexByEntry[index], entryGeometries.indices.contains(geometryIndex) else { return nil }
        return entryGeometries[geometryIndex].frame
    }

    func register(_ geometryView: TranscriptEntryGeometryView, in scrollView: NSScrollView) {
        guard !isStopped else { return }
        self.geometryView = geometryView
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
                    MainActor.assumeIsolated {
                        self?.pendingRestoration = nil
                        self?.seekTargetStorage = nil
                    }
                }
                .store(in: &observations)
            monitorScrollWheel()
            trackPointer(in: scrollView)
        }
        geometryDidLayout()
        scheduleUpdate()
    }

    func unregister(_ geometryView: TranscriptEntryGeometryView) {
        if self.geometryView === geometryView { self.geometryView = nil }
    }

    func geometryDidLayout() {
        guard restoresDuringLayout, let index = pendingRestoration?.entryIndex,
            entryFrameInClipView(at: index) != nil
        else { return }
        restoresDuringLayout = false
        restorePositionIfNeeded()
    }

    func stop() {
        isStopped = true
        seekTargetStorage = nil
        observations.removeAll()
        geometryView = nil
        entryGeometries.removeAll()
        geometryIndexByEntry.removeAll()
        if let scrollWheelMonitor { NSEvent.removeMonitor(scrollWheelMonitor) }
        scrollWheelMonitor = nil
        pointerTracking?.remove()
        pointerTracking = nil
        pointerLocation = nil
    }

    private func trackPointer(in scrollView: NSScrollView) {
        pointerTracking?.remove()
        pointerTracking = TranscriptPointerTracking(controller: self, view: scrollView)
    }

    func pointerMoved(to locationInWindow: CGPoint) {
        guard !isStopped else { return }
        pointerLocation = locationInWindow
        pointerMovedSinceSeek = true
        readingUpdates.send()
    }

    func pointerLeft() {
        guard pointerLocation != nil else { return }
        pointerLocation = nil
        readingUpdates.send()
    }

    func entryIDAtPointer() -> Int? {
        guard let pointerLocation, let scrollView, let geometryView, geometryView.enclosingScrollView === scrollView,
            scrollView.window != nil, !entryGeometries.isEmpty
        else { return nil }
        let clipView = scrollView.contentView
        let point = clipView.convert(pointerLocation, from: nil)
        let readable = Self.readableBounds(of: clipView)
        guard point.y >= readable.minY, point.y <= readable.maxY else { return nil }
        let y = geometryView.convert(point, from: clipView).y
        var low = 0
        var high = entryGeometries.count - 1
        var found: Int?
        while low <= high {
            let middle = (low + high) / 2
            if entryGeometries[middle].frame.minY <= y {
                found = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return found.map { entryGeometries[$0].entryIndex }
    }

    private func monitorScrollWheel() {
        if let scrollWheelMonitor { NSEvent.removeMonitor(scrollWheelMonitor) }
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let scrollView = self.scrollView, event.window === scrollView.window,
                    scrollView.bounds.contains(scrollView.convert(event.locationInWindow, from: nil))
                else { return }
                self.handOverToScrolling()
            }
            return event
        }
    }

    /// A mouse wheel posts no live-scroll notification, and neither does momentum after a page loads, so without this
    /// the restoration pulled the view back on every update until the wheel stopped.
    func handOverToScrolling() {
        seekTargetStorage = nil
        guard pendingRestoration != nil, hasAppliedRestoration else { return }
        pendingRestoration = nil
        restorationGeometry = nil
    }

    func restore(_ position: TranscriptReadingPosition, duringNextLayout: Bool = false) {
        pendingRestoration = position
        restorationGeometry = nil
        hasAppliedRestoration = false
        restoresDuringLayout = duringNextLayout && position.entryIndex != nil
        if restoresDuringLayout { geometryView?.needsLayout = true }
        scheduleUpdate()
    }

    func restoreRecordedPosition() {
        guard pendingRestoration == nil, let position = positionStore.position(for: conversationID) else { return }
        restore(position)
        if let index = position.entryIndex { entrySeekingRequests.send(index) }
    }

    private func scheduleUpdate() {
        guard !hasScheduledUpdate, !isStopped else { return }
        hasScheduledUpdate = true
        let delay = pendingRestoration == nil ? 0.0 : Self.delayForSwiftUIToCommitRowMeasurements
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.hasScheduledUpdate = false
            self.restorePositionIfNeeded()
            self.forgetSeekTargetOutOfView()
            let hasReadingPosition = self.recordPosition()
            if hasReadingPosition, let viewport = self.pagingViewport { self.viewportUpdates.send(viewport) }
            self.readingUpdates.send()
        }
    }

    private func restorePositionIfNeeded() {
        guard let pendingRestoration, let scrollView, let documentView = scrollView.documentView,
            scrollView.contentView.bounds.height > 0, documentView.bounds.height > 0
        else { return }
        let clipView = scrollView.contentView
        var proposedBounds = clipView.bounds
        var restoredEntryFrame: NSRect?
        switch pendingRestoration {
        case .bottom:
            proposedBounds.origin.y = clipView.documentRect.maxY - proposedBounds.height
        case .entry(let index, let offset):
            guard let entryFrame = entryFrameInClipView(at: index), entryFrame.height > 0 else { return }
            restoredEntryFrame = entryFrame
            proposedBounds.origin.y = entryFrame.minY + min(offset, max(0, entryFrame.height - 1)) - clipView.contentInsets.top
        }
        let geometry = RestorationGeometry(
            documentRect: clipView.documentRect, viewportBounds: clipView.bounds, entryFrame: restoredEntryFrame)
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
        guard let position = currentReadingPosition() else { return false }
        positionStore.record(position, for: conversationID)
        return true
    }

    func currentReadingPosition() -> TranscriptReadingPosition? {
        guard pendingRestoration == nil, !isStopped, let scrollView, let geometryView,
            geometryView.enclosingScrollView === scrollView
        else { return nil }
        let clipView = scrollView.contentView
        if tracksTranscriptBottom, clipView.documentRect.maxY - clipView.bounds.maxY <= 2 { return .bottom }
        let visibleBounds = Self.readableBounds(of: clipView)
        let localVisibleBounds = geometryView.convert(visibleBounds, from: clipView)
        guard let geometry = firstGeometry(overlapping: localVisibleBounds) else { return nil }
        let entryFrame = geometryView.convert(geometry.frame, to: clipView)
        return .entry(index: geometry.entryIndex, offset: visibleBounds.minY - entryFrame.minY)
    }

    func visibleEntryFrames() -> [CGRect] {
        guard let scrollView, let geometryView, geometryView.enclosingScrollView === scrollView else { return [] }
        let clipView = scrollView.contentView
        let localVisibleBounds = geometryView.convert(clipView.bounds, from: clipView)
        guard let first = firstGeometryIndex(overlapping: localVisibleBounds) else { return [] }
        return entryGeometries[first...].prefix { $0.frame.minY < localVisibleBounds.maxY }
            .map { geometryView.convert($0.frame, to: clipView) }
    }

    private var seekTargetStorage: Int? {
        didSet { if let seekTargetStorage, seekTargetStorage != oldValue { pointerMovedSinceSeek = false } }
    }

    var seekTarget: Int? {
        forgetSeekTargetOutOfView()
        return seekTargetStorage
    }

    private func forgetSeekTargetOutOfView() {
        guard let index = seekTargetStorage, pendingRestoration == nil, let frame = entryFrameInClipView(at: index),
            let clipView = scrollView?.contentView, !frame.intersects(Self.readableBounds(of: clipView))
        else { return }
        seekTargetStorage = nil
    }

    func seek(toEntryAt index: Int) {
        seekTargetStorage = index
        positionStore.record(.startOfEntry(index), for: conversationID)
        restore(.startOfEntry(index))
        entrySeekingRequests.send(index)
    }

    func setSeekTarget(_ index: Int, recordingPosition: Bool = false) {
        seekTargetStorage = index
        if recordingPosition { positionStore.record(.startOfEntry(index), for: conversationID) }
    }

    func clearSeekTarget() { seekTargetStorage = nil }

    func visibleEntryIDs(minimumVisibleHeight: CGFloat) -> [Int] {
        guard let scrollView, let geometryView, geometryView.enclosingScrollView === scrollView else { return [] }
        let bounds = geometryView.convert(Self.readableBounds(of: scrollView.contentView), from: scrollView.contentView)
        guard let first = firstGeometryIndex(overlapping: bounds) else { return [] }
        return entryGeometries[first...].prefix { $0.frame.minY < bounds.maxY }
            .filter { min($0.frame.maxY, bounds.maxY) - max($0.frame.minY, bounds.minY) >= minimumVisibleHeight }
            .map(\.entryIndex)
    }

    static func readableBounds(of clipView: NSClipView) -> CGRect {
        let insets = clipView.contentInsets
        var bounds = clipView.bounds
        bounds.origin.y += insets.top
        bounds.size.height = max(0, bounds.height - insets.top - insets.bottom)
        return bounds
    }

    func entryFrameInClipView(at index: Int) -> CGRect? {
        guard let geometryIndex = geometryIndexByEntry[index], entryGeometries.indices.contains(geometryIndex),
            let scrollView, let geometryView, geometryView.enclosingScrollView === scrollView
        else { return nil }
        return geometryView.convert(entryGeometries[geometryIndex].frame, to: scrollView.contentView)
    }

    private func firstGeometry(overlapping bounds: CGRect) -> TranscriptEntryGeometry? {
        firstGeometryIndex(overlapping: bounds).map { entryGeometries[$0] }
    }

    private func firstGeometryIndex(overlapping bounds: CGRect) -> Int? {
        var lowerBound = 0
        var upperBound = entryGeometries.count
        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if entryGeometries[middle].frame.maxY <= bounds.minY {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }
        guard lowerBound < entryGeometries.count, entryGeometries[lowerBound].frame.minY < bounds.maxY else { return nil }
        return lowerBound
    }
}

/// The tracking area over a reader's scroll view, with its owner, which the area doesn't keep.
@MainActor
private final class TranscriptPointerTracking {
    private let area: NSTrackingArea
    private let owner: TranscriptPointerTrackingOwner
    private weak var view: NSView?

    init(controller: TranscriptScrollPositionController, view: NSView) {
        owner = TranscriptPointerTrackingOwner(controller: controller)
        area = NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: owner, userInfo: nil)
        self.view = view
        view.addTrackingArea(area)
    }

    func remove() { view?.removeTrackingArea(area) }
}

@MainActor
private final class TranscriptPointerTrackingOwner: NSResponder {
    weak var controller: TranscriptScrollPositionController?

    init(controller: TranscriptScrollPositionController) {
        self.controller = controller
        super.init()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseMoved(with event: NSEvent) { controller?.pointerMoved(to: event.locationInWindow) }
    override func mouseEntered(with event: NSEvent) { controller?.pointerMoved(to: event.locationInWindow) }
    override func mouseExited(with event: NSEvent) { controller?.pointerLeft() }
}
