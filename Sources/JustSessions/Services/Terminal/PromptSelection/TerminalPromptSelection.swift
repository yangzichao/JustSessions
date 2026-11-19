import AppKit

/// ⌘A in a CLI's terminal selects only the text in the CLI's prompt, as in a text field, when the terminal finds the
/// prompt on its screen with the caret in it; see `CLIPromptLayout`. Without one, or while the prompt shows no text,
/// ⌘A selects all of the terminal as before.
///
/// The CLI knows nothing of this selection, so the terminal draws it over the CLI's text, and acts on it by sending the
/// CLI the keys that do the same: ⌘C copies the text the rows show, Delete deletes it, and typing or pasting replaces
/// it; see `PromptSelectionKeyAction` and `CLIPromptEditingKeys`. Any other key goes to the CLI as usual and ends the
/// selection, as do a click and the prompt changing on screen.
@MainActor
final class TerminalPromptSelection {
    /// How the tab's CLI draws its prompt; nil for a CLI the terminal can't find it in.
    var layout: CLIPromptLayout?
    private(set) var selectedPrompt: CLIPrompt?
    var isActive: Bool { selectedPrompt != nil }
    /// Where Copy puts the prompt's text; a test gives its own.
    var pasteboard = NSPasteboard.general

    /// How long the screen stays unchanged before the prompt on it is checked again. Ghostty reads output on its own
    /// thread, and a CLI redraws its screen in a few writes.
    static let screenSettleDelay: Duration = .milliseconds(50)

    private weak var terminal: (any PromptSelectableTerminal)?
    private var overlay: TerminalPromptSelectionOverlay?
    // periphery:ignore - held so the monitor lasts as long as the selection.
    private var eventMonitor: PromptSelectionEventMonitor?
    private var screenCheck: Task<Void, Never>?

    init(terminal: any PromptSelectableTerminal) {
        self.terminal = terminal
    }

    /// Selects the prompt's text for ⌘A, and returns whether there was any. While the terminal's own selection holds
    /// text, ⌘A selects all of the terminal instead, as it does again while the prompt is selected.
    func selectPrompt() -> Bool {
        guard let layout, let terminal, !terminal.hasMarkedText(), !terminal.selectionActive,
            let screen = terminal.screenForPromptSelection(), let prompt = layout.prompt(on: screen)
        else { return false }
        show(prompt)
        eventMonitor = PromptSelectionEventMonitor(
            matching: [.keyDown, .leftMouseDown, .otherMouseDown, .scrollWheel],
            handleEvent: { [weak self] event in self?.letsGoOn(event) ?? true },
            handleMenuAction: { [weak self] actionName in self?.menuWillSend(actionName) }
        )
        return true
    }

    /// Does what a key does to the selected prompt, and returns whether the key is done with; a key that isn't goes
    /// on to the terminal as usual.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let selectedPrompt, let terminal else { return false }
        guard terminal.window?.firstResponder === terminal, !terminal.selectionActive else {
            cancel()
            return false
        }
        switch PromptSelectionKeyAction(event) {
        case .copy:
            copy(selectedPrompt)
            return true
        case .cut:
            copy(selectedPrompt)
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return true
        case .delete:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return true
        case .replace:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return false
        case .moveToStart:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.movingToStart(of: selectedPrompt))
            return true
        case .moveToEnd:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.movingToEnd(of: selectedPrompt))
            return true
        case .selectAllTerminalText:
            cancel()
            terminal.selectAllTerminalText()
            return true
        case .dismiss:
            cancel()
            return true
        case .passThrough:
            cancel()
            return false
        }
    }

    /// The menus' Copy: copies the selected prompt's text and returns true, unless the terminal's own selection has
    /// taken its place since.
    func copySelectedPrompt() -> Bool {
        guard let selectedPrompt, let terminal else { return false }
        guard !terminal.selectionActive else {
            cancel()
            return false
        }
        copy(selectedPrompt)
        return true
    }

    /// The menus' Paste, before the paste goes in: deletes the selected prompt, which the paste then replaces.
    func deleteSelectedPromptForPaste() {
        guard let selectedPrompt, let terminal else { return }
        cancel()
        guard !terminal.selectionActive else { return }
        terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
    }

    /// Called after output reaches the terminal. Once the screen settles, a prompt that shows the same text stays
    /// selected, where it moved to; one that changed ends the selection.
    func terminalOutputArrived() {
        guard isActive else { return }
        screenCheck?.cancel()
        screenCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.screenSettleDelay)
            guard !Task.isCancelled else { return }
            self?.checkPromptOnScreen()
        }
    }

    /// Ends the selection and stops drawing it.
    func cancel() {
        selectedPrompt = nil
        overlay?.removeFromSuperview()
        overlay = nil
        eventMonitor = nil
        screenCheck?.cancel()
        screenCheck = nil
    }

    func checkPromptOnScreen() {
        guard let selectedPrompt, let layout, let terminal,
            let screen = terminal.screenForPromptSelection(), let prompt = layout.prompt(on: screen),
            prompt.text == selectedPrompt.text
        else {
            cancel()
            return
        }
        if prompt != selectedPrompt { show(prompt) }
    }

    private func show(_ prompt: CLIPrompt) {
        guard let terminal else { return }
        selectedPrompt = prompt
        let overlay = overlay ?? TerminalPromptSelectionOverlay(frame: terminal.bounds)
        if overlay.superview == nil {
            overlay.autoresizingMask = [.width, .height]
            terminal.addSubview(overlay, positioned: .above, relativeTo: nil)
            self.overlay = overlay
        }
        overlay.frame = terminal.bounds
        let cellsFrame = { (columns: Range<Int>, row: Int) in
            terminal.frame(ofCells: columns, inRow: row).map { overlay.convert($0, from: terminal) }
        }
        var lineFrames: [NSRect] = []
        var glyphs: [TerminalPromptSelectionOverlay.Glyph] = []
        for line in prompt.lines where line.cellCount > 0 {
            guard let lineFrame = cellsFrame(line.startColumn..<(line.startColumn + line.cellCount), line.row) else { continue }
            lineFrames.append(lineFrame)
            let row = TerminalScreenRow(line.text)
            for (index, character) in row.characters.enumerated() where !TerminalScreenRow.isBlank(character) {
                let column = line.startColumn + row.startColumn(ofCharacterAt: index)
                let cellCount = TerminalCellWidth.cellCount(of: character)
                guard let frame = cellsFrame(column..<(column + cellCount), line.row) else { continue }
                glyphs.append(TerminalPromptSelectionOverlay.Glyph(character: character, frame: frame))
            }
        }
        overlay.show(lineFrames: lineFrames, glyphs: glyphs, style: terminal.promptSelectionTextStyle)
    }

    /// The event monitor's: whether `event` goes on as usual after what it did to the selection.
    private func letsGoOn(_ event: NSEvent) -> Bool {
        guard let terminal, event.window === terminal.window else { return true }
        switch event.type {
        case .keyDown:
            return !handleKeyDown(event)
        case .scrollWheel:
            if terminal.bounds.contains(terminal.convert(event.locationInWindow, from: nil)) { cancel() }
            return true
        default:
            cancel()
            return true
        }
    }

    /// The Edit menu's Paste replaces the prompt, as the right-click menu's does, and its Select All selects all of the
    /// terminal. Copy reaches the terminal's own `copy(_:)`, which copies the prompt.
    private func menuWillSend(_ actionName: String) {
        guard let terminal, terminal.window?.firstResponder === terminal else { return }
        switch actionName {
        case NSStringFromSelector(#selector(NSText.paste(_:))): deleteSelectedPromptForPaste()
        case NSStringFromSelector(#selector(NSResponder.selectAll(_:))): cancel()
        default: break
        }
    }

    private func copy(_ prompt: CLIPrompt) {
        pasteboard.clearContents()
        pasteboard.setString(prompt.text, forType: .string)
    }
}
