import AppKit

@testable import JustSessions

/// A tab's SwiftTerm terminal in a window that is never shown, as `GhosttyTestTerminal` is for Ghostty.
@MainActor
final class SwiftTermTestTerminal {
    let window: NSWindow
    let view: SelectableTerminalView

    init(stores: IsolatedAppearanceStores, frame: NSRect) {
        window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        view = SelectableTerminalView(frame: frame, appearanceStore: stores.appearance, themeStore: stores.theme)
        window.contentView = view
    }

    deinit {
        MainActor.assumeIsolated {
            window.contentView = nil
            window.close()
        }
    }

    func show(_ output: String) {
        view.feed(text: output)
    }

    /// SwiftTerm keeps its cell size to itself, but the frame it asks for grows by a cell for each column or row.
    var cellPixelSize: TerminalCellPixelSize {
        let terminal = view.getTerminal()
        let (columns, rows) = (terminal.cols, terminal.rows)
        defer { terminal.resize(cols: columns, rows: rows) }
        terminal.resize(cols: 40, rows: 10)
        let smaller = view.getOptimalFrameSize()
        terminal.resize(cols: 50, rows: 20)
        let larger = view.getOptimalFrameSize()
        let scale = window.backingScaleFactor
        return TerminalCellPixelSize(
            width: Int(((larger.width - smaller.width) / 10 * scale).rounded()),
            height: Int(((larger.height - smaller.height) / 10 * scale).rounded())
        )
    }

    func snapshot() -> NSBitmapImageRep? {
        view.snapshotOverLayerBackground()
    }
}
