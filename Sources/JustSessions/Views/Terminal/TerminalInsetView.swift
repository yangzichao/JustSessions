import AppKit

/// Holds a tab's terminal in from the window's edges, in the terminal's own background color, so text never touches
/// the window's edge or the sidebar. The leading inset lines the first column up with the tab bar's labels. SwiftTerm
/// draws from its view's edge and already keeps the scroller's width free on the trailing side; for a terminal that
/// doesn't, the margin keeps that width free; see `TabTerminalView.trailingMarginWidth`.
final class TerminalInsetView: NSView {
    static let insets = NSEdgeInsets(top: 6, left: 16, bottom: 6, right: 0)

    let terminalView: any TabTerminalView

    init(terminalView: any TabTerminalView) {
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
            width: max(0, bounds.width - insets.left - insets.right - terminalView.trailingMarginWidth),
            height: max(0, bounds.height - insets.top - insets.bottom)
        )
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = terminalView.marginColor.cgColor
    }

    /// A tab moved to another window takes its terminal into that window's inset view.
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        guard terminalView.superview === self else { return }
        terminalView.frame = terminalFrame
    }

    /// A click in the margin puts the keyboard in the terminal, as a click on its text does.
    override func mouseDown(with event: NSEvent) {
        terminalView.onFocus?()
        window?.makeFirstResponder(terminalView)
    }

    /// So does a right-click there, which shows the terminal's menu.
    override func menu(for event: NSEvent) -> NSMenu? {
        terminalView.menu(for: event)
    }
}
