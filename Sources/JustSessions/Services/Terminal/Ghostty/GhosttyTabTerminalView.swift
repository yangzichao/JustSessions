import AppKit
import Carbon.HIToolbox
import Combine
import GhosttyTerminal
import SwiftTerm

final class GhosttyTabTerminalView: AppTerminalView, TabTerminalView {
    /// For a tab whose CLI runs in tmux, on this Mac or an SSH host; see `SelectableTerminalView.cliRunsInTmux`. Ghostty
    /// would send Shift-Return as `CSI 27 ; 2 ; 13 ~`, so the tab sends CSI u itself, and Control keys as
    /// `GhosttyTabTerminalView+ControlKeys` does.
    var cliRunsInTmux = false
    var onBackgroundColorChange: (() -> Void)?
    var onUnheardLightDarkChange: (() -> Void)?
    var onFocus: (() -> Void)?
    var makeContextMenu: ((_ linkUnderPointer: String?) -> NSMenu)?
    /// Shows that menu: AppKit's pop-up, which a test replaces, since a menu shown in a test run ends the run.
    var popUpContextMenu: (NSMenu, NSEvent, NSView) -> Void = NSMenu.popUpContextMenu(_:with:for:)
    var onOpenLink: ((String) -> Void)?
    var hoveredLink: String?
    var pendingHardWrappedLink: HardWrappedLink?
    var acceptsDroppedFiles = false {
        didSet {
            guard acceptsDroppedFiles != oldValue else { return }
            if acceptsDroppedFiles { registerForDraggedTypes([.fileURL]) } else { unregisterDraggedTypes() }
        }
    }
    var copyDroppedFilesToHost: ((_ fileURLs: [URL]) -> Bool)?
    let imagePaste = TerminalImagePaste()
    lazy var promptSelection = TerminalPromptSelection(terminal: self)
    private(set) var marginColor = NSColor.textBackgroundColor
    var trailingMarginWidth: CGFloat { NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay) }
    let inMemorySession: InMemoryTerminalSession
    private(set) weak var terminalSurface: TerminalSurface?

    private let processQueue = DispatchQueue(label: "JustSessions.GhosttyTabTerminalView.process")
    private let processDelegate: GhosttyProcessDelegate
    private lazy var process = LocalProcess(delegate: processDelegate, dispatchQueue: processQueue)
    let outputBackpressure: GhosttyOutputBackpressure
    private lazy var outputCoalescer: TerminalOutputCoalescer = {
        let coalescer = TerminalOutputCoalescer()
        coalescer.consume = { [weak self] bytes in self?.consumeOutput(bytes) }
        return coalescer
    }()
    private weak var processObserver: TerminalProcessObserver?
    private(set) var viewport: InMemoryTerminalViewport?
    var gridMetrics: TerminalGridMetrics?
    private(set) var appearancePreferences = TerminalAppearancePreferences()
    private var theme = ResolvedAppTheme(.justSessions)
    private var appearanceSubscription: AnyCancellable?
    private(set) var appliedPalette: TerminalPalette?
    private var themeReporting = TerminalThemeReporting()
    private var themeReportAfterBackgroundAnswer: String?
    private(set) var outputModeScanner = TerminalOutputModeScanner()

    override convenience init(frame: NSRect) {
        self.init(frame: frame, appearanceStore: .shared, themeStore: .shared)
    }

    init(
        frame: NSRect,
        appearanceStore: TerminalAppearanceStore,
        themeStore: AppThemeStore,
        optionKeyStore: TerminalOptionKeyStore = .shared,
        outputHighWaterByteCount: Int = GhosttyOutputBackpressure.defaultHighWaterByteCount,
        outputLowWaterByteCount: Int = GhosttyOutputBackpressure.defaultLowWaterByteCount
    ) {
        // Ghostty calls these on its IO thread; the view handles them on the main thread, in the order they came.
        let callbackTarget = MainThreadCallbackTarget()
        inMemorySession = InMemoryTerminalSession(
            write: { data in
                DispatchQueue.main.async { MainActor.assumeIsolated { callbackTarget.view?.sendToProcess(data) } }
            },
            resize: { viewport in
                DispatchQueue.main.async { MainActor.assumeIsolated { callbackTarget.view?.resizeProcessTerminal(to: viewport) } }
            }
        )
        outputBackpressure = GhosttyOutputBackpressure(
            session: inMemorySession,
            highWaterByteCount: outputHighWaterByteCount,
            lowWaterByteCount: outputLowWaterByteCount
        )
        processDelegate = GhosttyProcessDelegate(outputBackpressure: outputBackpressure)
        super.init(frame: frame)
        callbackTarget.view = self
        processDelegate.view = self
        delegate = self
        configuration = TerminalSurfaceOptions(backend: .inMemory(inMemorySession))
        controller = GhosttyTerminalControllers.shared.controller(
            appearanceStore: appearanceStore, themeStore: themeStore, optionKeyStore: optionKeyStore
        )
        observeAppearance(in: appearanceStore, themeStore: themeStore)
    }

    func setWorkspaceActive(_ isActive: Bool) {
        outputCoalescer.isActive = isActive
        if !isActive { promptSelection.cancel() }
        setSurfaceVisible(isActive)
    }

    func startProcess(executable: String, args: [String], environment: [String]?, execName: String?, currentDirectory: String?) {
        process.startProcess(
            executable: executable,
            args: args,
            environment: environment,
            execName: execName,
            currentDirectory: currentDirectory
        )
    }

    var processID: Int32 { process.shellPid }

    func terminate() {
        outputBackpressure.stop()
        let process = process
        processQueue.sync { process.terminate() }
    }

    deinit {
        outputBackpressure.stop()
    }

    func connectProcessObserver(_ observer: TerminalProcessObserver) {
        processObserver = observer
    }

    override func setFrameSize(_ newSize: NSSize) {
        outputCoalescer.flush()
        if newSize != frame.size { promptSelection.cancel() }
        super.setFrameSize(newSize)
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        window?.makeFirstResponder(self)
        super.mouseDown(with: eventFindingLinks(event))
    }

    override func mouseUp(with event: NSEvent) {
        pendingHardWrappedLink = event.modifierFlags.contains(.command) ? hardWrappedLink(under: event) : nil
        super.mouseUp(with: eventFindingLinks(event))
        if let pendingHardWrappedLink {
            self.pendingHardWrappedLink = nil
            onOpenLink?(pendingHardWrappedLink.text)
        }
    }
    override func mouseMoved(with event: NSEvent) { super.mouseMoved(with: eventFindingLinks(event)) }
    override func mouseDragged(with event: NSEvent) { super.mouseDragged(with: eventFindingLinks(event)) }

    /// While an input method composes text, Return belongs to it. tmux never turns on the kitty keyboard protocol for
    /// the tab, which is when the SwiftTerm tab leaves Shift-Return alone, so this one doesn't ask.
    override func keyDown(with event: NSEvent) {
        if cliRunsInTmux, ShiftReturnKey.matches(event), !hasMarkedText() {
            sendAsTyped(ShiftReturnKey.csiUSequence)
            return
        }
        if let pageKey = PageKey(event), !hasMarkedText(), !outputModeScanner.hasKittyKeyboardFlags {
            pressPageKey(pageKey)
            return
        }
        super.keyDown(with: event)
    }

    private func pressPageKey(_ pageKey: PageKey) {
        if outputModeScanner.isOnAlternateScreen {
            sendAsTyped(pageKey.sequence)
        } else {
            performBindingAction(pageKey.scrollAction)
        }
    }

    /// Sends a key's bytes as Ghostty sends the keys it encodes, from its IO thread, so they keep their place among
    /// the keys typed before them that Ghostty has not sent yet. Like a typed key, this scrolls to the bottom.
    func sendAsTyped(_ keyBytes: String) {
        performBindingAction(Self.textAction(typing: keyBytes))
    }

    /// Ghostty's `text:` binding action, whose text is a Zig string literal: each control character and backslash
    /// goes as `\xNN`.
    static func textAction(typing text: String) -> String {
        let literal = text.unicodeScalars.map { scalar in
            scalar.value < 0x20 || scalar.value == 0x7F || scalar == "\\"
                ? String(format: "\\x%02x", scalar.value)
                : String(scalar)
        }
        return "text:" + literal.joined()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateMarginColor()
    }

    private func sendToProcess(_ data: Data) {
        let bytes = Array(GhosttyThemeReportFilter.removingThemeReports(from: data))
        guard !bytes.isEmpty else { return }
        guard let report = themeReportAfterBackgroundAnswer,
            let answerEnd = GhosttyBackgroundColorAnswer.endIndex(in: bytes)
        else {
            process.send(data: bytes[...])
            return
        }
        themeReportAfterBackgroundAnswer = nil
        process.send(data: bytes[..<answerEnd])
        sendTerminalReport(report)
        if answerEnd < bytes.endIndex { process.send(data: bytes[answerEnd...]) }
    }

    private func consumeOutput(_ bytes: ArraySlice<UInt8>) {
        let owedReportAfterBackgroundQuery = themeReporting.reportsAfterNextBackgroundQuery
        var themeReportsToSendAfterFeeding = themeReporting.reportsToSendAfterTheTerminalReads(
            bytes, isDark: appliedPalette?.isDark ?? false)
        if owedReportAfterBackgroundQuery, !themeReporting.reportsAfterNextBackgroundQuery {
            themeReportAfterBackgroundAnswer = themeReportsToSendAfterFeeding.popLast()
        }
        outputModeScanner.scan(bytes)
        inMemorySession.receive(Data(bytes))
        outputBackpressure.outputPassedToGhostty(byteCount: bytes.count)
        themeReportsToSendAfterFeeding.forEach(sendTerminalReport)
        promptSelection.terminalOutputArrived()
    }

    var reportsThemeAfterNextBackgroundQuery: Bool { themeReporting.reportsAfterNextBackgroundQuery }

    var isOnAlternateScreen: Bool { outputModeScanner.isOnAlternateScreen }

    var isBracketedPasteOn: Bool { outputModeScanner.isBracketedPasteOn }

    func reportThemeAfterNextBackgroundQuery() {
        themeReporting.reportAfterNextBackgroundQuery()
    }

    func cancelThemeReportAfterNextBackgroundQuery() {
        themeReporting.cancelReportAfterNextBackgroundQuery()
    }

    private func sendTerminalReport(_ report: String) {
        process.send(data: Array(report.utf8)[...])
    }

    fileprivate func receiveProcessOutput(_ bytes: [UInt8]) {
        outputCoalescer.receive(bytes[...])
    }

    fileprivate func reportProcessExit(rawWaitStatus: Int32?) {
        outputCoalescer.flush()
        processObserver?.processEnded(rawWaitStatus: rawWaitStatus)
    }

    private func resizeProcessTerminal(to viewport: InMemoryTerminalViewport) {
        self.viewport = viewport
        guard process.running else { return }
        var size = Self.windowSize(of: viewport)
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    var processWindowSize: winsize {
        viewport.map(Self.windowSize(of:)) ?? estimatedWindowSize
    }

    private static func windowSize(of viewport: InMemoryTerminalViewport) -> winsize {
        winsize(
            ws_row: viewport.rows,
            ws_col: viewport.columns,
            ws_xpixel: UInt16(clamping: viewport.widthPixels),
            ws_ypixel: UInt16(clamping: viewport.heightPixels)
        )
    }

    /// The grid a process started before Ghostty has laid out any text gets: what the view's frame holds at the
    /// terminal font's size, which Ghostty corrects once it lays the text out. It has a size in pixels too, as a
    /// SwiftTerm tab's does. With none, tmux asks the terminal for its size, and Ghostty, not laid out yet, answers
    /// with a provisional grid; an answer that reached tmux after Ghostty's first resize kept the CLI that small.
    private var estimatedWindowSize: winsize {
        let preferences = appearancePreferences.validated
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        let cellWidth = font.maximumAdvancement.width
        let cellHeight = (font.ascender - font.descender + font.leading).rounded(.up)
        guard cellWidth > 0, cellHeight > 0 else { return winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0) }
        var columns = Int(bounds.width / cellWidth)
        var rows = Int(bounds.height / cellHeight)
        if columns <= 0 || rows <= 0 { (columns, rows) = (80, 24) }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        return winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: columns),
            ws_xpixel: UInt16(clamping: Int(CGFloat(columns) * cellWidth * scale)),
            ws_ypixel: UInt16(clamping: Int(CGFloat(rows) * cellHeight * scale))
        )
    }

    private func observeAppearance(in store: TerminalAppearanceStore, themeStore: AppThemeStore) {
        appearanceSubscription = store.$terminalPreferences.combineLatest(themeStore.$terminalTheme).sink {
            [weak self] preferences, theme in
            guard let self else { return }
            appearancePreferences = preferences
            self.theme = theme
            appearance = TerminalAppearanceStyling.nativeAppearance(for: preferences, theme: theme)
            updateMarginColor()
        }
    }

    private func updateMarginColor() {
        let preferences = appearancePreferences.validated
        let usesDarkColors = preferences.mode.usesDarkColors(effectiveAppearance: effectiveAppearance)
        let palette = preferences.colorVariants(appTheme: theme).palette(usesDarkColors: usesDarkColors)
        marginColor = NSColor(hexValue: palette.background)
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

extension GhosttyTabTerminalView: TerminalSurfaceTitleDelegate {
    func terminalDidChangeTitle(_ title: String) {
        processObserver?.titleChanged(title)
    }
}

extension GhosttyTabTerminalView: TerminalSurfaceLifecycleDelegate {
    func terminalDidAttachSurface(_ surface: TerminalSurface) {
        terminalSurface = surface
    }

    func terminalDidDetachSurface() {
        terminalSurface = nil
    }
}

/// A Ghostty tab's `LocalProcess` delegate, which `LocalProcess` calls on `processQueue`, except `getWindowSize`.
/// `LocalProcess` holds its delegate for each call, also while a read waits for room, so the delegate is not the view:
/// a waiting read would keep a closed tab's view alive, and its last release, on `processQueue`, could free its Ghostty
/// surface off the main thread. The view is reached only on the main thread.
private final class GhosttyProcessDelegate: LocalProcessDelegate, @unchecked Sendable {
    private let outputBackpressure: GhosttyOutputBackpressure
    @MainActor weak var view: GhosttyTabTerminalView?

    init(outputBackpressure: GhosttyOutputBackpressure) {
        self.outputBackpressure = outputBackpressure
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        outputBackpressure.waitForRoom()
        let bytes = Array(slice)
        outputBackpressure.outputHandedToMainThread(byteCount: bytes.count)
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.view?.receiveProcessOutput(bytes) }
        }
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.view?.reportProcessExit(rawWaitStatus: exitCode) }
        }
    }

    func getWindowSize() -> winsize {
        // `LocalProcess` asks only from `startProcess`, which the tab calls on the main thread.
        MainActor.assumeIsolated {
            view?.processWindowSize ?? winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        }
    }
}

private enum PageKey {
    case up
    case down

    init?(_ event: NSEvent) {
        guard event.type == .keyDown, event.modifierFlags.intersection([.control, .option, .command]).isEmpty else { return nil }
        switch Int(event.keyCode) {
        case kVK_PageUp: self = .up
        case kVK_PageDown: self = .down
        default: return nil
        }
    }

    var sequence: String {
        switch self {
        case .up: "\u{1B}[5~"
        case .down: "\u{1B}[6~"
        }
    }

    var scrollAction: String {
        switch self {
        case .up: "scroll_page_up"
        case .down: "scroll_page_down"
        }
    }
}

private final class MainThreadCallbackTarget: @unchecked Sendable {
    weak var view: GhosttyTabTerminalView?
}
