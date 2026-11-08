import AppKit

/// A tab's terminal, whichever engine draws it: what the tab, its inset view, and the workspace ask of it. Finding text
/// in it is `TerminalTextFinding`.
@MainActor
protocol TabTerminalView: NSView, TerminalTextFinding {
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
    /// Builds the menu a right-click on the terminal or its margin shows, with the link under the pointer, if any; see
    /// `TerminalContextMenu`.
    var makeContextMenu: ((_ linkUnderPointer: String?) -> NSMenu)? { get set }
    /// Called with the link ⌘-clicked in the terminal: an OSC 8 hyperlink's target, or the URL or path the engine found
    /// under the pointer, all of it when a CLI broke it over rows (`HardWrappedLink`). Nothing opens without it; the
    /// tab's view in its window sets it, see `TerminalLinkActions+Click`.
    var onOpenLink: ((String) -> Void)? { get set }
    /// The link a ⌘-click where `event` happened would hand to `onOpenLink`; nil outside the terminal's text.
    func link(under event: NSEvent) -> String?
    /// Whether text is selected, which the menu's Copy needs.
    var selectionActive: Bool { get }
    /// ⌘A's selection of the CLI's prompt, which the menu's Copy also copies and its Paste replaces.
    var promptSelection: TerminalPromptSelection { get }
    /// The menu's Copy and Paste. Select All is `NSResponder`'s `selectAll(_:)`, which both engines implement.
    func copy(_ sender: Any)
    func paste(_ sender: Any)
    /// The terminal's background, which the margin around it takes on; see `TerminalInsetView`.
    var marginColor: NSColor { get }
    /// The space the margin keeps free after the terminal's trailing edge, so its text lines up the same whichever
    /// engine draws it.
    var trailingMarginWidth: CGFloat { get }
    /// For a tab whose CLI runs in tmux, on this Mac or an SSH host; see `SelectableTerminalView.cliRunsInTmux`.
    var cliRunsInTmux: Bool { get set }
    /// The terminal shows the alternate screen, which keeps no scrollback, as a tmux client's terminal does.
    var isOnAlternateScreen: Bool { get }
    /// The terminal takes files dropped on it. Every tab turns it on.
    var acceptsDroppedFiles: Bool { get set }
    /// Takes the files dropped on a tab whose CLI runs on an SSH host, which copies them there before typing the host's
    /// paths, and returns whether it took them; see `TerminalSSHFileDrop`. Without it, a drop types the files' paths.
    var copyDroppedFilesToHost: ((_ fileURLs: [URL]) -> Bool)? { get set }
    /// What the menus' Paste and ⌘V do with only an image on the clipboard; a tab on an SSH host sets its
    /// `copyToHost`.
    var imagePaste: TerminalImagePaste { get }
    /// Types each path, backslash-escaped, as its own paste, as a drop does; see `TerminalFileDropPaste`. Returns
    /// whether every path went in.
    @discardableResult
    func typeDroppedPaths(_ paths: [String]) -> Bool
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
    var isOnAlternateScreen: Bool { terminal.isCurrentBufferAlternate }

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
