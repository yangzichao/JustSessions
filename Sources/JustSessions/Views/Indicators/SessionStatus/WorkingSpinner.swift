import AppKit
import QuartzCore
import SwiftUI

/// The arc is a Core Animation layer turned by the render server, not a SwiftUI animation: a `TimelineView` ticking
/// 30 times a second made the window's whole hosting view re-render on every tick, about a quarter of the main
/// thread's time at idle with one CLI working; see item 19 in docs/development/performance.md.
struct WorkingSpinner: View {
    static let secondsPerTurn = 0.9

    var holdsStill = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WorkingSpinnerArc(turns: !reduceMotion && !holdsStill)
            .frame(width: InterfaceScale.points(8), height: InterfaceScale.points(8))
    }
}

struct WorkingSpinnerArc: NSViewRepresentable {
    let turns: Bool

    func makeNSView(context: Context) -> WorkingSpinnerArcView {
        WorkingSpinnerArcView()
    }

    func updateNSView(_ view: WorkingSpinnerArcView, context: Context) {
        view.turns = turns
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WorkingSpinnerArcView, context: Context) -> CGSize? {
        CGSize(width: InterfaceScale.points(8), height: InterfaceScale.points(8))
    }
}

final class WorkingSpinnerArcView: NSView {
    private static let rotationKey = "turn"

    var turns = true {
        didSet { if turns != oldValue { updateRotation() } }
    }

    private let arcLayer = CAShapeLayer()
    private var hostAlphaObservation: NSKeyValueObservation?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(arcLayer)
        arcLayer.fillColor = nil
        arcLayer.lineWidth = 1.6
        arcLayer.lineCap = .round
        arcLayer.strokeStart = 0
        arcLayer.strokeEnd = 0.72
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Flipped, as SwiftUI's coordinates are, so the arc starts at the top as the SwiftUI arc did: a `Circle` path
    /// starts at the right and runs clockwise in a flipped space, and so does the layer's, leaving the gap in the same
    /// place with Reduce Motion on.
    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let side = min(bounds.width, bounds.height)
        let frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        arcLayer.frame = frame
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(origin: .zero, size: frame.size))
        arcLayer.path = path
        updateStrokeColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStrokeColor()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        // SwiftUI hides content it keeps mounted with `opacity(0)`, which reaches AppKit as the hosting superview's
        // alpha, not as `isHidden`.
        hostAlphaObservation = superview?.observe(\.alphaValue, options: [.initial]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.updateRotation() }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Selector observers are dropped with the view; a minimized window keeps the view attached and tells no
        // other method.
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSWindow.didMiniaturizeNotification, object: nil)
        center.removeObserver(self, name: NSWindow.didDeminiaturizeNotification, object: nil)
        if let window {
            center.addObserver(
                self, selector: #selector(windowMiniaturizationChanged), name: NSWindow.didMiniaturizeNotification, object: window)
            center.addObserver(
                self, selector: #selector(windowMiniaturizationChanged), name: NSWindow.didDeminiaturizeNotification, object: window)
        }
        updateRotation()
    }

    @objc private func windowMiniaturizationChanged(_: Notification) {
        updateRotation()
    }

    override func viewDidHide() {
        super.viewDidHide()
        updateRotation()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        updateRotation()
    }

    private func updateStrokeColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            arcLayer.strokeColor = ThemePalette.liveNSColor.cgColor
        }
    }

    var canBeSeen: Bool {
        guard let window, !window.isMiniaturized, !isHiddenOrHasHiddenAncestor else { return false }
        return (superview?.alphaValue ?? 1) > 0
    }

    var isTurning: Bool {
        arcLayer.animation(forKey: Self.rotationKey) != nil
    }

    private func updateRotation() {
        if turns && canBeSeen {
            guard !isTurning else { return }
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = 2 * Double.pi
            rotation.duration = WorkingSpinner.secondsPerTurn
            rotation.repeatCount = .infinity
            rotation.isRemovedOnCompletion = false
            arcLayer.add(rotation, forKey: Self.rotationKey)
        } else {
            arcLayer.removeAnimation(forKey: Self.rotationKey)
        }
    }
}
