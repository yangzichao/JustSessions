import AppKit

/// Holds a tab's terminal in from the window's edges, in the terminal's own background color, so text never touches
/// the window's edge or the sidebar. The leading inset lines the first column up with the tab bar's labels. SwiftTerm
/// draws from its view's edge and already keeps the scroller's width free on the trailing side.
final class TerminalInsetView: NSView {
    static let insets = NSEdgeInsets(top: 6, left: 16, bottom: 6, right: 0)

    let terminalView: SelectableTerminalView

    init(terminalView: SelectableTerminalView) {
        self.terminalView = terminalView
        super.init(frame: terminalView.frame)
        wantsLayer = true
        addSubview(terminalView)
        terminalView.frame = terminalFrame
        terminalView.onBackgroundColorChange = { [weak self] in self?.needsDisplay = true }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("TerminalInsetView is created in code") }

    private var terminalFrame: NSRect {
        let insets = Self.insets
        return NSRect(
            x: insets.left,
            y: insets.bottom,
            width: max(0, bounds.width - insets.left - insets.right),
            height: max(0, bounds.height - insets.top - insets.bottom)
        )
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = terminalView.nativeBackgroundColor.cgColor
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        terminalView.frame = terminalFrame
    }

    /// A click in the margin puts the keyboard in the terminal, as a click on its text does.
    override func mouseDown(with event: NSEvent) {
        terminalView.onMouseDown?()
        window?.makeFirstResponder(terminalView)
    }
}
