import AppKit

@MainActor
final class TerminalPromptSelection {
    var layout: CLIPromptLayout?
    private(set) var selectedPrompt: CLIPrompt?
    var isActive: Bool { selectedPrompt != nil }
    var pasteboard = NSPasteboard.general

    static let screenSettleDelay: Duration = .milliseconds(50)

    private weak var terminal: (any PromptSelectableTerminal)?
    private var overlay: TerminalPromptSelectionOverlay?
    // periphery:ignore - held so the monitor lasts as long as the selection.
    private var eventMonitor: PromptSelectionEventMonitor?
    private var screenCheck: Task<Void, Never>?

    init(terminal: any PromptSelectableTerminal) {
        self.terminal = terminal
    }

    func selectPrompt() -> Bool {
        guard let layout, let terminal, !terminal.hasMarkedText(), !terminal.selectionActive,
            let screen = terminal.screenForPromptSelection(), let prompt = layout.prompt(on: screen)
        else { return false }
        show(prompt)
        eventMonitor = PromptSelectionEventMonitor(
            matching: [.keyDown, .leftMouseDown, .otherMouseDown, .scrollWheel],
            handleEvent: { [weak self] event in self?.handleMonitoredEvent(event) ?? .goesOnAsUsual },
            handleMenuAction: { [weak self] actionName in self?.menuWillSend(actionName) }
        )
        return true
    }

    func handleKeyDown(_ event: NSEvent) -> PromptSelectionEventHandling {
        guard let selectedPrompt, let terminal else { return .goesOnAsUsual }
        guard terminal.window?.firstResponder === terminal, !terminal.selectionActive else {
            cancel()
            return .goesOnAsUsual
        }
        switch PromptSelectionKeyAction(event) {
        case .copy:
            copy(selectedPrompt)
            return .handledBySelection
        case .cut:
            copy(selectedPrompt)
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return .handledBySelection
        case .delete:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return .handledBySelection
        case .replace:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
            return .goesOnAsUsual
        case .moveToStart:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.movingToStart(of: selectedPrompt))
            return .handledBySelection
        case .moveToEnd:
            cancel()
            terminal.typeForPromptSelection(CLIPromptEditingKeys.movingToEnd(of: selectedPrompt))
            return .handledBySelection
        case .selectAllTerminalText:
            cancel()
            terminal.selectAllTerminalText()
            return .handledBySelection
        case .dismiss:
            cancel()
            return .handledBySelection
        case .passThrough:
            cancel()
            return .goesOnAsUsual
        }
    }

    func copySelectedPrompt() -> Bool {
        guard let selectedPrompt, let terminal else { return false }
        guard !terminal.selectionActive else {
            cancel()
            return false
        }
        copy(selectedPrompt)
        return true
    }

    func deleteSelectedPromptForPaste() {
        guard let selectedPrompt, let terminal else { return }
        cancel()
        guard !terminal.selectionActive else { return }
        terminal.typeForPromptSelection(CLIPromptEditingKeys.clearing(selectedPrompt))
    }

    func terminalOutputArrived() {
        guard isActive else { return }
        screenCheck?.cancel()
        screenCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.screenSettleDelay)
            guard !Task.isCancelled else { return }
            self?.checkPromptOnScreen()
        }
    }

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

    private func handleMonitoredEvent(_ event: NSEvent) -> PromptSelectionEventHandling {
        guard let terminal, event.window === terminal.window else { return .goesOnAsUsual }
        switch event.type {
        case .keyDown:
            return handleKeyDown(event)
        case .scrollWheel:
            if terminal.bounds.contains(terminal.convert(event.locationInWindow, from: nil)) { cancel() }
            return .goesOnAsUsual
        default:
            cancel()
            return .goesOnAsUsual
        }
    }

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
