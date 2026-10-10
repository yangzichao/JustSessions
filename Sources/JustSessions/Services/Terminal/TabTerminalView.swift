import AppKit

/// A tab's terminal, whichever engine draws it: what the tab, its inset view, and the workspace ask of it.
@MainActor
protocol TabTerminalView: NSView {
    /// Called when a click lands on the terminal or its margin, or files are dropped on it, before the terminal takes
    /// the keyboard, so a split pane whose tab is not selected can select it.
    var onFocus: (() -> Void)? { get set }
    /// Called after the terminal's colors are set, so the margin around it can match its background.
    var onBackgroundColorChange: (() -> Void)? { get set }
    /// Called when the terminal's colors turn from light to dark or back while no program in it subscribes to theme
    /// changes; see `ConversationStore+RemoteTmuxColors`.
    var onUnheardLightDarkChange: (() -> Void)? { get set }
    /// Whether a theme report is owed after the next background query; see `reportThemeAfterNextBackgroundQuery()`.
    var reportsThemeAfterNextBackgroundQuery: Bool { get }
    /// Reports the current theme once the terminal has answered the next background query (`OSC 11 ; ?`), even though
    /// no program subscribes to theme changes.
    func reportThemeAfterNextBackgroundQuery()
    func cancelThemeReportAfterNextBackgroundQuery()
    /// Builds the menu a right-click on the terminal or its margin shows; see `TerminalContextMenu`.
    var makeContextMenu: (() -> NSMenu)? { get set }
    /// Whether text is selected, which the menu's Copy needs.
    var selectionActive: Bool { get }
    /// The menu's Copy and Paste. Select All is `NSResponder`'s `selectAll(_:)`, which both engines implement.
    func copy(_ sender: Any)
    func paste(_ sender: Any)
    /// The terminal's background, which the margin around it takes on; see `TerminalInsetView`.
    var marginColor: NSColor { get }
    /// The space the margin keeps free after the terminal's trailing edge, so its text lines up the same whichever
    /// engine draws it.
    var trailingMarginWidth: CGFloat { get }
    /// For a tab whose CLI runs in tmux on this Mac; see `SelectableTerminalView.sendsShiftReturnAsCSIu`.
    var sendsShiftReturnAsCSIu: Bool { get set }
    /// Files dropped on the terminal type their paths into it. Only a tab whose CLI runs on this Mac turns it on.
    var acceptsDroppedFiles: Bool { get set }
    /// The terminal is on screen, full width or as either half of a split, so it draws its output.
    func setWorkspaceActive(_ isActive: Bool)
    /// Starts the tab's process on a pseudo-terminal, as a child of the app.
    func startProcess(executable: String, args: [String], environment: [String]?, execName: String?, currentDirectory: String?)
    /// The tab's process, or 0 until it starts.
    var processID: Int32 { get }
    /// Sends the tab's process SIGTERM and stops reading from it; see `TerminalSession.close()`.
    func terminate()
    /// The observer hears the titles the process sets and how it ends.
    func connectProcessObserver(_ observer: TerminalProcessObserver)
}

extension SelectableTerminalView: TabTerminalView {
    var marginColor: NSColor { nativeBackgroundColor }
    /// None: SwiftTerm keeps its scroller's width free inside its own view.
    var trailingMarginWidth: CGFloat { 0 }
    var processID: Int32 { process.shellPid }

    func connectProcessObserver(_ observer: TerminalProcessObserver) {
        processDelegate = observer
    }
}

extension TerminalEngine {
    /// A new tab's terminal, drawn by this engine.
    @MainActor
    func makeTabTerminalView(frame: NSRect) -> any TabTerminalView {
        switch self {
        case .ghostty: GhosttyTabTerminalView(frame: frame)
        case .swiftTerm: SelectableTerminalView(frame: frame)
        }
    }
}
