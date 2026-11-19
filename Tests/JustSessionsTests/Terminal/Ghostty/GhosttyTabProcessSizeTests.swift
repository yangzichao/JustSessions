import AppKit
import Testing

@testable import JustSessions

@MainActor
struct GhosttyTabProcessSizeTests {
    /// A process started before Ghostty lays out its text gets a size in pixels too, as in a SwiftTerm tab. With none,
    /// tmux asks the terminal for its size, and Ghostty answers with a provisional grid; when that answer reached tmux
    /// after Ghostty's first resize, the CLI in tmux stayed laid out at the provisional grid.
    @Test(arguments: [NSSize(width: 900, height: 600), NSSize(width: 1, height: 1)])
    func processStartedBeforeLayoutGetsASizeInPixels(frameSize: NSSize) {
        let view = GhosttyTabTerminalView(frame: NSRect(origin: .zero, size: frameSize))
        #expect(view.viewport == nil)

        let size = view.processWindowSize
        #expect(size.ws_col > 0 && size.ws_row > 0)
        #expect(size.ws_xpixel > 0 && size.ws_ypixel > 0)
    }
}
