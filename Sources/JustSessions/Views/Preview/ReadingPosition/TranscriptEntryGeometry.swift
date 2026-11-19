import AppKit
import SwiftUI

struct TranscriptEntryGeometry: Equatable {
    let entryIndex: Int
    let frame: CGRect
}

struct TranscriptEntryGeometryLayout: Layout {
    let entryIndices: [Int]
    let controller: TranscriptScrollPositionController

    static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.reduce(into: CGSize.zero) { size, subview in
            let childSize = subview.sizeThatFits(proposal)
            size.width = max(size.width, childSize.width)
            size.height += childSize.height
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        var geometries: [TranscriptEntryGeometry] = []
        geometries.reserveCapacity(subviews.count)
        for (index, subview) in zip(entryIndices, subviews) {
            let childProposal = ProposedViewSize(width: bounds.width, height: nil)
            let childSize = subview.sizeThatFits(childProposal)
            subview.place(
                at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: childSize.height)
            )
            geometries.append(
                TranscriptEntryGeometry(
                    entryIndex: index,
                    frame: CGRect(x: 0, y: y - bounds.minY, width: bounds.width, height: childSize.height)
                ))
            y += childSize.height
        }
        MainActor.assumeIsolated { controller.updateEntryGeometries(geometries) }
    }
}

struct TranscriptEntryGeometryObserver: NSViewRepresentable {
    let controller: TranscriptScrollPositionController

    func makeNSView(context: Context) -> TranscriptEntryGeometryView {
        TranscriptEntryGeometryView(controller: controller)
    }

    func updateNSView(_ view: TranscriptEntryGeometryView, context: Context) {
        view.registerPosition()
    }

    static func dismantleNSView(_ view: TranscriptEntryGeometryView, coordinator: ()) {
        view.stopTracking()
    }
}

final class TranscriptEntryGeometryView: NSView {
    override var isFlipped: Bool { true }

    let controller: TranscriptScrollPositionController
    private var isTracking = true

    init(controller: TranscriptScrollPositionController) {
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
        controller.geometryDidLayout()
    }

    func registerPosition() {
        guard isTracking, let scrollView = enclosingScrollView else { return }
        controller.register(self, in: scrollView)
    }

    func stopTracking() {
        isTracking = false
        controller.unregister(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
