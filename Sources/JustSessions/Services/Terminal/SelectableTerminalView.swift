import AppKit
import Combine
import SwiftTerm

final class SelectableTerminalView: LocalProcessTerminalView {
    /// For a tab whose CLI runs in tmux, on this Mac or an SSH host, which encodes each key again for the CLI; see
    /// `ThisMacTmuxServer.globalOptions` and `RemoteCLICommandBuilder`. SwiftTerm tells Shift-Return from Return only
    /// once the CLI turns on the kitty keyboard protocol, which tmux never does with the tab. So the tab sends
    /// Shift-Return as CSI u itself, and tmux hands it to the CLI unchanged. The tab also tells tmux which Control keys
    /// were pressed; see `TerminalControlKey`.
    var cliRunsInTmux = false
    var onBackgroundColorChange: (() -> Void)?
    /// Called when the terminal's colors turn from light to dark or back while no program in it subscribes to theme
    /// changes, as tmux before 3.6 does not; see `ConversationStore+RemoteTmuxColors`.
    var onUnheardLightDarkChange: (() -> Void)?
    var onFocus: (() -> Void)?
    var makeContextMenu: ((_ linkUnderPointer: String?) -> NSMenu)?
    var onOpenLink: ((String) -> Void)?
    var acceptsDroppedFiles = false {
        didSet {
            guard acceptsDroppedFiles != oldValue else { return }
            if acceptsDroppedFiles { registerForDraggedTypes([.fileURL]) } else { unregisterDraggedTypes() }
        }
    }
    var copyDroppedFilesToHost: ((_ fileURLs: [URL]) -> Bool)?
    let imagePaste = TerminalImagePaste()
    lazy var promptSelection = TerminalPromptSelection(terminal: self)

    private var appearancePreferences = TerminalAppearancePreferences()
    private var theme = ResolvedAppTheme(.justSessions)
    private var appearanceSubscription: AnyCancellable?
    private var optionKeySubscription: AnyCancellable?
    private var appliedPalette: TerminalPalette?
    private var themeReporting = TerminalThemeReporting()
    private lazy var outputCoalescer: TerminalOutputCoalescer = {
        let coalescer = TerminalOutputCoalescer()
        coalescer.consume = { [weak self] bytes in self?.consumeOutput(bytes) }
        return coalescer
    }()

    func setWorkspaceActive(_ isActive: Bool) {
        guard outputCoalescer.isActive != isActive else { return }
        outputCoalescer.isActive = isActive
        if !isActive { promptSelection.cancel() }
        // AppKit can also omit drawing and cursor subviews while this tab is invisible.
        isHidden = !isActive
        if isActive { needsDisplay = true }
    }

    override func dataReceived(slice: ArraySlice<UInt8>) { outputCoalescer.receive(slice) }

    private func consumeOutput(_ bytes: ArraySlice<UInt8>) {
        let themeReportsToSendAfterFeeding = themeReporting.reportsToSendAfterTheTerminalReads(
            bytes, isDark: appliedPalette?.isDark ?? false)
        feed(byteArray: bytes)
        themeReportsToSendAfterFeeding.forEach(sendTerminalReport)
        promptSelection.terminalOutputArrived()
    }

    /// Goes out as SwiftTerm's own replies do: unlike typing, it leaves the scroll position and selection alone.
    private func sendTerminalReport(_ report: String) {
        getTerminal().sendResponse(text: report)
    }

    var reportsThemeAfterNextBackgroundQuery: Bool { themeReporting.reportsAfterNextBackgroundQuery }

    func reportThemeAfterNextBackgroundQuery() {
        themeReporting.reportAfterNextBackgroundQuery()
    }

    func cancelThemeReportAfterNextBackgroundQuery() {
        themeReporting.cancelReportAfterNextBackgroundQuery()
    }

    override func setFrameSize(_ newSize: NSSize) {
        outputCoalescer.flush()
        if newSize != frame.size { promptSelection.cancel() }
        super.setFrameSize(newSize)
    }

    override func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        outputCoalescer.flush()
        super.processTerminated(source, exitCode: exitCode)
    }

    override convenience init(frame: CGRect) {
        self.init(frame: frame, appearanceStore: .shared, themeStore: .shared)
    }

    init(
        frame: CGRect,
        appearanceStore: TerminalAppearanceStore,
        themeStore: AppThemeStore,
        optionKeyStore: TerminalOptionKeyStore = .shared
    ) {
        super.init(frame: frame)
        getTerminal().changeScrollback(Self.scrollbackLineCount)
        observeAppearance(in: appearanceStore, themeStore: themeStore)
        observeOptionKey(in: optionKeyStore)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        getTerminal().changeScrollback(Self.scrollbackLineCount)
        observeAppearance(in: .shared, themeStore: .shared)
        observeOptionKey(in: .shared)
    }

    static let scrollbackLineCount = 10_000

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    /// The terminal takes the keyboard first, as a click gives it, so what the menu pastes and what is typed next both
    /// go to it, even from a split pane whose tab was not selected. SwiftTerm sends no right-click to the CLI, so the
    /// menu takes nothing from it.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let makeContextMenu else { return super.menu(for: event) }
        onFocus?()
        window?.makeFirstResponder(self)
        return makeContextMenu(link(under: event))
    }

    /// SwiftTerm calls this for a ⌘-click on a link, with an OSC 8 hyperlink's target or the URL or path it found. Its
    /// own version would hand any of them to `NSWorkspace`, whatever its scheme.
    override func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        onOpenLink?(link)
    }

    override func copy(_ sender: Any) {
        guard !promptSelection.copySelectedPrompt() else { return }
        super.copy(sender)
    }

    /// The menus' Paste replaces ⌘A's selected prompt, if any. With only an image on the clipboard, SwiftTerm's own
    /// paste sends an empty one, as a CLI on this Mac needs it; see `TerminalImagePaste`.
    override func paste(_ sender: Any) {
        promptSelection.deleteSelectedPromptForPaste()
        if imagePaste.handleClipboardImage() == .sendNothing { return }
        super.paste(sender)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)), promptSelection.isActive { return true }
        return super.validateUserInterfaceItem(item)
    }

    /// SwiftTerm's `keyDown` hands Return here; while an input method composes text, Return belongs to it.
    override func interpretKeyEvents(_ eventArray: [NSEvent]) {
        if cliRunsInTmux, terminal.keyboardEnhancementFlags.isEmpty, !hasMarkedText(),
            eventArray.count == 1, let event = eventArray.first, ShiftReturnKey.matches(event)
        {
            send(txt: ShiftReturnKey.csiUSequence)
            return
        }
        super.interpretKeyEvents(eventArray)
    }

    private func observeAppearance(in store: TerminalAppearanceStore, themeStore: AppThemeStore) {
        appearanceSubscription = store.$terminalPreferences.combineLatest(themeStore.$terminalTheme).sink {
            [weak self] preferences, theme in
            guard let self else { return }
            appearancePreferences = preferences
            self.theme = theme
            appearance = TerminalAppearanceStyling.nativeAppearance(for: preferences, theme: theme)
            applyAppearance()
        }
    }

    private func observeOptionKey(in store: TerminalOptionKeyStore) {
        optionKeySubscription = store.$optionIsMeta.sink { [weak self] optionIsMeta in
            self?.optionAsMetaKey = optionIsMeta
        }
    }

    private func applyAppearance() {
        let palette = TerminalAppearanceStyling.apply(appearancePreferences, theme: theme, to: self)
        onBackgroundColorChange?()
        guard palette != appliedPalette else { return }
        let previousPalette = appliedPalette
        appliedPalette = palette
        if let report = themeReporting.reportAfterColorChange(isDark: palette.isDark) {
            sendTerminalReport(report)
        } else if let previousPalette, previousPalette.isDark != palette.isDark {
            onUnheardLightDarkChange?()
        }
    }
}
