import AppKit
import SwiftTerm

/// Keeps the embedded CLI terminal usable as a native text surface.
final class SelectableTerminalView: LocalProcessTerminalView {
    var onSelectionChanged: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        applySystemAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applySystemAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySystemAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)
        onSelectionChanged?(selectionActive)
    }

    private func applySystemAppearance() {
        configureNativeColors()
        // The paper tint of the preview, so switching between a transcript and a terminal keeps the same surface.
        nativeBackgroundColor = ThemePalette.contentSurfaceNSColor.resolved(for: effectiveAppearance)
        selectedTextBackgroundColor = .selectedTextBackgroundColor
        selectedTextForegroundColor = .selectedTextColor
        caretColor = .textColor
        layer?.backgroundColor = nativeBackgroundColor.cgColor
        needsDisplay = true
    }
}
