import AppKit
import Testing
@testable import JustSessions

@MainActor
struct GhosttyTabTerminalViewTests {
    /// The margin around a Ghostty terminal takes on the background a SwiftTerm terminal draws with the same settings.
    @Test func theMarginFollowsTheTerminalBackgroundThroughThemeModeAndAppAppearanceChanges() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        parent.appearance = NSAppearance(named: .darkAqua)
        let frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let ghosttyView = GhosttyTabTerminalView(frame: frame, appearanceStore: store, themeStore: themeStore)
        let swiftTermView = SelectableTerminalView(frame: frame, appearanceStore: store, themeStore: themeStore)
        parent.addSubview(ghosttyView)
        parent.addSubview(swiftTermView)
        var backgroundChanges = 0
        ghosttyView.onBackgroundColorChange = { backgroundChanges += 1 }

        store.setMode(.dark)
        themeStore.setTheme(.gruvbox)
        #expect(ghosttyView.marginColor == NSColor(hexValue: AppThemeColors.gruvboxDark.contentSurface))
        #expect(ghosttyView.marginColor == swiftTermView.marginColor)

        store.setMode(.light)
        #expect(ghosttyView.marginColor == NSColor(hexValue: AppThemeColors.gruvboxLight.contentSurface))

        store.setColorChoice(.preset(.dracula))
        #expect(ghosttyView.marginColor == NSColor(hexValue: TerminalPalette.dracula.background))
        #expect(ghosttyView.marginColor == swiftTermView.marginColor)

        store.setColorChoice(.matchAppTheme)
        store.setMode(.matchApp)
        #expect(ghosttyView.marginColor == NSColor(hexValue: AppThemeColors.gruvboxDark.contentSurface))
        parent.appearance = NSAppearance(named: .aqua)
        // Deliver AppKit's appearance callback explicitly because this view is not in an onscreen window.
        ghosttyView.viewDidChangeEffectiveAppearance()
        swiftTermView.viewDidChangeEffectiveAppearance()
        #expect(ghosttyView.marginColor == NSColor(hexValue: AppThemeColors.gruvboxLight.contentSurface))
        #expect(ghosttyView.marginColor == swiftTermView.marginColor)
        #expect(backgroundChanges >= 6)
    }

    /// SwiftTerm keeps its scroller's width free inside its view; the margin keeps the same width free beside a Ghostty
    /// terminal, so text ends at the same place in both.
    @Test func theTextEndsWhereASwiftTermTerminalsTextEnds() throws {
        let frame = NSRect(x: 0, y: 0, width: 800, height: 500)
        let swiftTermView = SelectableTerminalView(frame: frame)
        let ghosttyView = GhosttyTabTerminalView(frame: frame)
        let swiftTermInset = TerminalInsetView(terminalView: swiftTermView)
        let ghosttyInset = TerminalInsetView(terminalView: ghosttyView)
        for insetView in [swiftTermInset, ghosttyInset] {
            insetView.setFrameSize(frame.size)
            insetView.layoutSubtreeIfNeeded()
        }
        let scroller = try #require(swiftTermView.subviews.first { $0 is NSScroller })

        #expect(scroller.frame.width > 0)
        #expect(ghosttyView.frame.minX == swiftTermView.frame.minX)
        #expect(ghosttyView.frame.maxX == swiftTermView.frame.minX + scroller.frame.minX)
        #expect(ghosttyView.frame.height == swiftTermView.frame.height)
    }

    /// A click on a split pane's terminal selects its tab, then gives the terminal the keyboard.
    @Test(arguments: TerminalEngine.allCases)
    func clickingTheTerminalSelectsItsTabAndTakesTheKeyboard(_ engine: TerminalEngine) throws {
        _ = NSApplication.shared
        let terminalView = engine.makeTabTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = terminalView
        defer { window.close() }
        window.makeFirstResponder(nil)
        var focusRequests = 0
        terminalView.onFocus = { focusRequests += 1 }

        terminalView.mouseDown(with: try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: CGPoint(x: 100, y: 100), modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        )))

        #expect(focusRequests == 1)
        #expect(window.firstResponder === terminalView)
    }
}
