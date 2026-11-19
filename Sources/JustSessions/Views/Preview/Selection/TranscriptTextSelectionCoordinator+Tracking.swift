import AppKit

/// AppKit's own drag selection stays inside the text view it started in.
extension TranscriptTextSelectionCoordinator {
    private static let clickTolerance: CGFloat = 3

    func trackSelection(startingWith event: NSEvent, in view: TranscriptTextView) -> Bool {
        guard event.clickCount == 1, event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
            let window = view.window, let clickedPosition = position(at: event.locationInWindow, in: window)
        else { return false }
        let extendsSelection = event.modifierFlags.contains(.shift)
        let anchor = extendsSelection ? selection?.anchor ?? clickedPosition : clickedPosition
        if window.firstResponder !== view { window.makeFirstResponder(view) }
        select(TranscriptTextSelection(anchor: anchor, focus: clickedPosition), in: window)

        isTracking = true
        eventSource.startTracking()
        defer {
            eventSource.stopTracking()
            isTracking = false
            trackingEnded.send()
        }
        var latestDrag = event
        var hasDragged = false
        while let nextEvent = eventSource.nextEvent(window) {
            switch nextEvent.type {
            case .leftMouseUp:
                if !hasDragged, !extendsSelection { view.openLink(atWindowPoint: event.locationInWindow) }
                return true
            case .leftMouseDragged:
                latestDrag = nextEvent
                hasDragged =
                    hasDragged
                    || hypot(
                        nextEvent.locationInWindow.x - event.locationInWindow.x,
                        nextEvent.locationInWindow.y - event.locationInWindow.y) > Self.clickTolerance
                extendSelection(to: nextEvent.locationInWindow, in: window)
                autoscroll(with: nextEvent)
            default:
                let location = window.mouseLocationOutsideOfEventStream
                guard
                    let scrollEvent = NSEvent.mouseEvent(
                        with: .leftMouseDragged, location: location, modifierFlags: latestDrag.modifierFlags,
                        timestamp: nextEvent.timestamp,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                    )
                else { continue }
                if autoscroll(with: scrollEvent) { extendSelection(to: location, in: window) }
            }
        }
        return true
    }

    func extendSelection(to point: NSPoint, in window: NSWindow) {
        guard let anchor = selection?.anchor, let focus = position(at: point, in: window) else { return }
        let extendedSelection = TranscriptTextSelection(anchor: anchor, focus: focus)
        if extendedSelection != selection { select(extendedSelection, in: window) }
    }

    func position(at point: NSPoint, in window: NSWindow) -> TranscriptTextSelectionPosition? {
        let blocks = orderedViews.compactMap { key, view -> (key: TranscriptTextSelectionKey, view: TranscriptTextView, frame: NSRect)? in
            view.window === window ? (key, view, view.convert(view.bounds, to: nil)) : nil
        }
        guard let lastBlock = blocks.last else { return nil }
        if let block = blocks.first(where: { $0.frame.contains(point) }) {
            return TranscriptTextSelectionPosition(key: block.key, offset: block.view.insertionOffset(atWindowPoint: point))
        }
        let blocksOnLine = blocks.filter { $0.frame.minY <= point.y && point.y <= $0.frame.maxY }
        if let block = blocksOnLine.min(by: {
            Self.horizontalDistance(from: point, to: $0.frame) < Self.horizontalDistance(from: point, to: $1.frame)
        }) {
            let pointInBlock = NSPoint(x: min(max(point.x, block.frame.minX), block.frame.maxX), y: point.y)
            return TranscriptTextSelectionPosition(key: block.key, offset: block.view.insertionOffset(atWindowPoint: pointInBlock))
        }
        // Window coordinates rise upward, so a block below the point lies entirely under its y.
        if let blockBelow = blocks.first(where: { $0.frame.maxY < point.y }) {
            return TranscriptTextSelectionPosition(key: blockBelow.key, offset: 0)
        }
        return TranscriptTextSelectionPosition(key: lastBlock.key, offset: lastBlock.view.textLength)
    }

    private static func horizontalDistance(from point: NSPoint, to frame: NSRect) -> CGFloat {
        point.x < frame.minX ? frame.minX - point.x : max(0, point.x - frame.maxX)
    }

    @discardableResult
    private func autoscroll(with event: NSEvent) -> Bool {
        let focusView = selection.flatMap { view(for: $0.focus.key) }
        var ancestor = focusView?.superview
        var didScroll = false
        while let view = ancestor {
            if let clipView = view as? NSClipView, clipView.autoscroll(with: event) { didScroll = true }
            ancestor = view.superview
        }
        return didScroll
    }
}
