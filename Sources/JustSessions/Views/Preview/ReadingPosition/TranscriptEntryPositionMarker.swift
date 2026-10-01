import AppKit
import SwiftUI

/// A noninteractive marker lets the scroll controller measure the exact position inside a tall message.
struct TranscriptEntryPositionMarker: NSViewRepresentable {
    let entryIndex: Int
    let controller: TranscriptScrollPositionController

    func makeNSView(context: Context) -> TranscriptEntryPositionMarkerView {
        TranscriptEntryPositionMarkerView(entryIndex: entryIndex, controller: controller)
    }

    func updateNSView(_ marker: TranscriptEntryPositionMarkerView, context: Context) {
        marker.registerPosition()
    }

    static func dismantleNSView(_ marker: TranscriptEntryPositionMarkerView, coordinator: ()) {
        marker.stopTracking()
    }
}

final class TranscriptEntryPositionMarkerView: NSView {
    let entryIndex: Int
    private weak var controller: TranscriptScrollPositionController?
    private var isTracking = true

    init(entryIndex: Int, controller: TranscriptScrollPositionController) {
        self.entryIndex = entryIndex
        self.controller = controller
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerPosition()
    }

    override func layout() {
        super.layout()
        registerPosition()
    }

    func registerPosition() {
        guard isTracking, let scrollView = enclosingScrollView else { return }
        controller?.register(self, in: scrollView)
    }

    func stopTracking() {
        isTracking = false
        controller?.unregister(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
