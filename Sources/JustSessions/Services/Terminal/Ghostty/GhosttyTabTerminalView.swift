import AppKit
import Carbon.HIToolbox
import Combine
import GhosttyTerminal
import SwiftTerm

/// A tab's terminal drawn by Ghostty. The app runs the tab's process on a pseudo-terminal of its own, as it does for
/// SwiftTerm's, and hands Ghostty the output; Ghostty hands back what you type and the size it lays the text out at.
/// Ghostty's colors and font come from its controller's configuration; see `GhosttyTerminalControllers`.
final class GhosttyTabTerminalView: AppTerminalView, TabTerminalView {
    /// For a tab whose CLI runs in tmux on this Mac; see `SelectableTerminalView.sendsShiftReturnAsCSIu`. Ghostty
    /// would send Shift-Return as `CSI 27 ; 2 ; 13 ~`, so the tab sends CSI u itself.
    var sendsShiftReturnAsCSIu = false
    var onBackgroundColorChange: (() -> Void)?
    /// See `SelectableTerminalView.onUnheardLightDarkChange`.
    var onUnheardLightDarkChange: (() -> Void)?
    var onFocus: (() -> Void)?
    /// Builds the menu a right-click shows in place of Ghostty's own; see `GhosttyTabTerminalView+ContextMenu`.
    var makeContextMenu: (() -> NSMenu)?
    /// Shows that menu: AppKit's pop-up, which a test replaces, since a menu shown in a test run ends the run.
    var popUpContextMenu: (NSMenu, NSEvent, NSView) -> Void = NSMenu.popUpContextMenu(_:with:for:)
    /// Files dropped on the terminal type their paths into it; see `SelectableTerminalView.acceptsDroppedFiles`.
    var acceptsDroppedFiles = false {
        didSet {
            guard acceptsDroppedFiles != oldValue else { return }
            if acceptsDroppedFiles { registerForDraggedTypes([.fileURL]) } else { unregisterDraggedTypes() }
        }
    }
    private(set) var marginColor = NSColor.textBackgroundColor
    /// The width a SwiftTerm terminal keeps free for its scroller, which Ghostty doesn't draw, so text lines up the
    /// same in both.
    var trailingMarginWidth: CGFloat { NSScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay) }
    /// Where the process's output goes to Ghostty, and what Ghostty's screen shows.
    let inMemorySession: InMemoryTerminalSession
    /// Ghostty's surface while it has one, which holds the selection.
    private(set) weak var terminalSurface: TerminalSurface?

    /// Where `LocalProcess` hands over the process's output and exit. Off the main thread, so the reading can wait
    /// for Ghostty to catch up; see `GhosttyOutputBackpressure`.
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
    /// The grid Ghostty last laid the text out at, which the pseudo-terminal reports to the process.
    private(set) var viewport: InMemoryTerminalViewport?
    private var appearancePreferences = TerminalAppearancePreferences()
    private var theme = ResolvedAppTheme(.justSessions)
    private var appearanceSubscription: AnyCancellable?
    /// The colors the terminal last took on, so a theme report goes out only when they change.
    private var appliedPalette: TerminalPalette?
    private var themeReporting = TerminalThemeReporting()
    /// The report owed after a background query that Ghostty has been handed but not answered yet; see
    /// `sendToProcess(_:)`.
    private var themeReportAfterBackgroundAnswer: String?
    /// The screen and keyboard modes the process's output last set, for Page Up and Page Down.
    private var pageKeyModeScanner = TerminalPageKeyModeScanner()

    override convenience init(frame: NSRect) {
        self.init(frame: frame, appearanceStore: .shared, themeStore: .shared)
    }

    /// The output limits are `GhosttyOutputBackpressure`'s; a test can make them small.
    init(
        frame: NSRect,
        appearanceStore: TerminalAppearanceStore,
        themeStore: AppThemeStore,
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
        controller = GhosttyTerminalControllers.shared.controller(appearanceStore: appearanceStore, themeStore: themeStore)
        observeAppearance(in: appearanceStore, themeStore: themeStore)
    }

    func setWorkspaceActive(_ isActive: Bool) {
        outputCoalescer.isActive = isActive
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

    /// Closing a tab whose process still runs. The reading stops first: a read waiting for room on `processQueue`
    /// waits for the main thread, which would wait for it here forever.
    func terminate() {
        outputBackpressure.stop()
        // On the queue `LocalProcess` reports the exit on, so the two never run at once.
        let process = process
        processQueue.sync { process.terminate() }
    }

    /// A tab whose process already ended goes away without `terminate()` (see `TerminalSession.close()`), while a
    /// job the process left behind may still be writing. A read waiting for room then stops waiting rather than wait
    /// for a terminal that is gone.
    deinit {
        outputBackpressure.stop()
    }

    func connectProcessObserver(_ observer: TerminalProcessObserver) {
        processObserver = observer
    }

    override func setFrameSize(_ newSize: NSSize) {
        // Output that arrived at the old size is parsed at it before Ghostty lays the text out again.
        outputCoalescer.flush()
        super.setFrameSize(newSize)
    }

    override func mouseDown(with event: NSEvent) {
        onFocus?()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    /// While an input method composes text, Return belongs to it. tmux never turns on the kitty keyboard protocol for
    /// the tab, which is when the SwiftTerm tab leaves Shift-Return alone, so this one doesn't ask.
    override func keyDown(with event: NSEvent) {
        if sendsShiftReturnAsCSIu, ShiftReturnKey.matches(event), !hasMarkedText() {
            sendAsTyped(ShiftReturnKey.csiUSequence)
            return
        }
        if let pageKey = PageKey(event), !hasMarkedText(), !pageKeyModeScanner.hasKittyKeyboardFlags {
            pressPageKey(pageKey)
            return
        }
        super.keyDown(with: event)
    }

    /// As in a SwiftTerm tab while the program hasn't turned on the kitty keyboard protocol: on the main screen the
    /// key scrolls the scrollback a page and sends nothing; on the alternate screen it sends the key, without Shift.
    /// Ghostty would always send it, with Shift when held. Under the kitty protocol a SwiftTerm tab sends the key,
    /// encoded under it, on either screen, so then this tab leaves the key to Ghostty, which also sends it encoded.
    private func pressPageKey(_ pageKey: PageKey) {
        if pageKeyModeScanner.isOnAlternateScreen {
            sendAsTyped(pageKey.sequence)
        } else {
            performBindingAction(pageKey.scrollAction)
        }
    }

    /// Sends a key's bytes as Ghostty sends the keys it encodes, from its IO thread, so they keep their place among
    /// the keys typed before them that Ghostty has not sent yet. Like a typed key, this scrolls to the bottom.
    private func sendAsTyped(_ keyBytes: String) {
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

    /// What Ghostty sends the process: typing, pastes, and its replies to the process's requests. A theme report owed
    /// after a background query follows Ghostty's answer to it, as in a SwiftTerm tab, which reports once it has read
    /// the query and answered it. Ghostty answers on its IO thread, after `consumeOutput` handed it the query, so the
    /// report waits here for the answer rather than going out from `consumeOutput` ahead of it.
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

    /// Hands output to Ghostty and answers the theme report requests in it, which the tab answers instead of Ghostty.
    /// A report owed after a background query waits for Ghostty's answer; see `sendToProcess(_:)`.
    private func consumeOutput(_ bytes: ArraySlice<UInt8>) {
        let owedReportAfterBackgroundQuery = themeReporting.reportsAfterNextBackgroundQuery
        var themeReports = themeReporting.reports(answering: bytes, isDark: appliedPalette?.isDark ?? false)
        if owedReportAfterBackgroundQuery, !themeReporting.reportsAfterNextBackgroundQuery {
            // The query was in this output. Every report from one call is the same, so any of them can be the owed one.
            themeReportAfterBackgroundAnswer = themeReports.popLast()
        }
        pageKeyModeScanner.scan(bytes)
        inMemorySession.receive(Data(bytes))
        outputBackpressure.outputPassedToGhostty(byteCount: bytes.count)
        themeReports.forEach(sendTerminalReport)
    }

    var reportsThemeAfterNextBackgroundQuery: Bool { themeReporting.reportsAfterNextBackgroundQuery }

    func reportThemeAfterNextBackgroundQuery() {
        themeReporting.reportAfterNextBackgroundQuery()
    }

    /// Leaves a report already waiting for Ghostty's answer to go out, as a SwiftTerm tab would have sent it already.
    func cancelThemeReportAfterNextBackgroundQuery() {
        themeReporting.cancelReportAfterNextBackgroundQuery()
    }

    /// Goes straight to the process, unlike typing, which would scroll Ghostty to the bottom.
    private func sendTerminalReport(_ report: String) {
        process.send(data: Array(report.utf8)[...])
    }

    fileprivate func receiveProcessOutput(_ bytes: [UInt8]) {
        outputCoalescer.receive(bytes[...])
    }

    /// The process's output stays on screen, as in a SwiftTerm tab; the tab's bar says the CLI ended.
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

    fileprivate var processWindowSize: winsize {
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
    /// terminal font's size, which Ghostty corrects once it lays the text out.
    private var estimatedWindowSize: winsize {
        let preferences = appearancePreferences.validated
        let font = preferences.fontFamily.font(size: preferences.fontSize)
        let cellWidth = font.maximumAdvancement.width
        let cellHeight = (font.ascender - font.descender + font.leading).rounded(.up)
        guard cellWidth > 0, cellHeight > 0 else { return winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0) }
        let columns = Int(bounds.width / cellWidth)
        let rows = Int(bounds.height / cellHeight)
        guard columns > 0, rows > 0 else { return winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0) }
        return winsize(ws_row: UInt16(clamping: rows), ws_col: UInt16(clamping: columns), ws_xpixel: 0, ws_ypixel: 0)
    }

    private func observeAppearance(in store: TerminalAppearanceStore, themeStore: AppThemeStore) {
        appearanceSubscription = store.$preferences.combineLatest(themeStore.$terminalTheme).sink { [weak self] preferences, theme in
            guard let self else { return }
            appearancePreferences = preferences
            self.theme = theme
            appearance = TerminalAppearanceStyling.nativeAppearance(for: preferences, theme: theme)
            updateMarginColor()
        }
    }

    /// The background Ghostty draws with the same settings, which the controller's configuration gives it, and a
    /// theme report when those colors change.
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

    /// Waits while too much output is unparsed, which pauses reading the pseudo-terminal, then hands the output to
    /// the main thread.
    func dataReceived(slice: ArraySlice<UInt8>) {
        outputBackpressure.waitForRoom()
        let bytes = Array(slice)
        outputBackpressure.outputHandedToMainThread(byteCount: bytes.count)
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.view?.receiveProcessOutput(bytes) }
        }
    }

    /// Goes to the main thread the way output does, from the same queue, so it comes after the output read before it.
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

/// Page Up or Page Down, also as Fn-↑ or Fn-↓, alone or with Shift.
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

/// Lets Ghostty's IO-thread callbacks, which the session holds from before the view exists, reach the view. Only
/// read and written on the main thread.
private final class MainThreadCallbackTarget: @unchecked Sendable {
    weak var view: GhosttyTabTerminalView?
}
