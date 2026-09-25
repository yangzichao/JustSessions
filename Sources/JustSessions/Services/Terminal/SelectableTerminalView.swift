import AppKit
import SwiftTerm

/// Keeps the embedded CLI terminal usable as a native text surface.
final class SelectableTerminalView: LocalProcessTerminalView {
    var onSelectionChanged: ((Bool) -> Void)?
    /// For a tab whose CLI runs in tmux on this Mac. SwiftTerm tells Shift-Return from Return only once the CLI
    /// turns on the kitty keyboard protocol, which tmux never does with the tab. So the tab sends Shift-Return as
    /// CSI u itself, and tmux hands it to the CLI unchanged; see `ThisMacTmuxServer.globalOptions`.
    var sendsShiftReturnAsCSIu = false

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

    /// SwiftTerm's `keyDown` hands Return here; while an input method composes text, Return belongs to it.
    override func interpretKeyEvents(_ eventArray: [NSEvent]) {
        if sendsShiftReturnAsCSIu, terminal.keyboardEnhancementFlags.isEmpty, !hasMarkedText(),
           eventArray.count == 1, let event = eventArray.first, ShiftReturnKey.matches(event) {
            send(txt: ShiftReturnKey.csiUSequence)
            return
        }
        super.interpretKeyEvents(eventArray)
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
