import AppKit

@MainActor
protocol TabTerminalView: NSView, TerminalTextFinding {
    var onFocus: (() -> Void)? { get set }
    var onBackgroundColorChange: (() -> Void)? { get set }
    var onUnheardLightDarkChange: (() -> Void)? { get set }
    var reportsThemeAfterNextBackgroundQuery: Bool { get }
    func reportThemeAfterNextBackgroundQuery()
    func cancelThemeReportAfterNextBackgroundQuery()
    var makeContextMenu: ((_ linkUnderPointer: String?) -> NSMenu)? { get set }
    var onOpenLink: ((String) -> Void)? { get set }
    func link(under event: NSEvent) -> String?
    var selectionActive: Bool { get }
    var promptSelection: TerminalPromptSelection { get }
    func copy(_ sender: Any)
    func paste(_ sender: Any)
    var marginColor: NSColor { get }
    var trailingMarginWidth: CGFloat { get }
    var cliRunsInTmux: Bool { get set }
    var isOnAlternateScreen: Bool { get }
    var acceptsDroppedFiles: Bool { get set }
    var copyDroppedFilesToHost: ((_ fileURLs: [URL]) -> Bool)? { get set }
    var imagePaste: TerminalImagePaste { get }
    @discardableResult
    func typeDroppedPaths(_ paths: [String]) -> Bool
    func setWorkspaceActive(_ isActive: Bool)
    func startProcess(executable: String, args: [String], environment: [String]?, execName: String?, currentDirectory: String?)
    var processID: Int32 { get }
    func terminate()
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
    @MainActor
    func makeTabTerminalView(frame: NSRect) -> any TabTerminalView {
        switch self {
        case .ghostty: GhosttyTabTerminalView(frame: frame)
        case .swiftTerm: SelectableTerminalView(frame: frame)
        }
    }
}
