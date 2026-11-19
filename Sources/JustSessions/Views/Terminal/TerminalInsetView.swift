import AppKit
import Combine

/// Holds a tab's terminal in from the window's edges, in the terminal's own background color, so text never touches
/// the window's edge or the sidebar. The leading inset lines the first column up with the tab bar's labels. SwiftTerm
/// draws from its view's edge and already keeps the scroller's width free on the trailing side; for a terminal that
/// doesn't, the margin keeps that width free; see `TabTerminalView.trailingMarginWidth`.
final class TerminalInsetView: NSView {
    static let insets = NSEdgeInsets(top: 6, left: 16, bottom: 6, right: 0)

    let terminalView: any TabTerminalView
    var isShown = true {
        didSet { applyWorkspaceActivity() }
    }
    var takesKeyboardInWindow = false
    private var windowObservations: Set<AnyCancellable> = []

    init(terminalView: any TabTerminalView) {
        self.terminalView = terminalView
        super.init(frame: terminalView.frame)
        wantsLayer = true
        addSubview(terminalView)
        terminalView.frame = terminalFrame
        terminalView.onBackgroundColorChange = { [weak self] in self?.needsDisplay = true }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservations.removeAll()
        if let window {
            for name in [NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
                NotificationCenter.default.publisher(for: name, object: window)
                    .sink { [weak self] _ in MainActor.assumeIsolated { self?.applyWorkspaceActivity() } }
                    .store(in: &windowObservations)
            }
        }
        applyWorkspaceActivity()
        if takesKeyboardInWindow, window != nil, terminalView.superview === self { takeKeyboard() }
    }

    /// Puts the keyboard in the terminal, or, while the terminal isn't in a window yet, as soon as this view brings it
    /// into one. SwiftUI can add a new tab's view to its window after the turn of the main queue that selected the tab
    /// gives it the keyboard on, when the app is busy.
    func takeKeyboard() {
        if let window = terminalView.window {
            takesKeyboardInWindow = false
            window.makeFirstResponder(terminalView)
        } else {
            takesKeyboardInWindow = terminalView.superview === self
        }
    }

    private func applyWorkspaceActivity() {
        terminalView.setWorkspaceActive(isShown && window?.isMiniaturized != true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("TerminalInsetView is created in code") }

    private var terminalFrame: NSRect {
        let insets = Self.insets
        return NSRect(
            x: insets.left,
            y: insets.bottom,
            width: max(0, bounds.width - insets.left - insets.right - terminalView.trailingMarginWidth),
            height: max(0, bounds.height - insets.top - insets.bottom)
        )
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = terminalView.marginColor.cgColor
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        guard terminalView.superview === self else { return }
        terminalView.frame = terminalFrame
    }

    override func mouseDown(with event: NSEvent) {
        terminalView.onFocus?()
        window?.makeFirstResponder(terminalView)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        terminalView.menu(for: event)
    }
}
