import AppKit
import SwiftTerm
import Testing
@testable import JustSessions

@MainActor
struct TerminalAppearanceRenderingTests {
    @Test func changingThemeUpdatesEveryTerminalWithoutDiscardingOutputOrSelection() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        store.setMode(.light)
        let first = makeTerminal(store: store)
        let second = makeTerminal(store: store)
        let originalEngine = first.getTerminal()
        first.feed(text: "Existing output\r\n\u{1B}[38;2;12;34;56mRGB text\u{1B}[0m")
        first.selectAll()
        let selectedOutput = first.getSelection()
        let originalFont = first.font

        store.setMode(.dark)

        #expect(first.getTerminal() === originalEngine)
        #expect(first.font == originalFont)
        #expect(first.selectionActive)
        #expect(first.getSelection() == selectedOutput)
        #expect(first.getTerminal().getCharData(col: 0, row: 1)?.attribute.fg == .trueColor(red: 12, green: 34, blue: 56))
        for terminalView in [first, second, makeTerminal(store: store)] {
            #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: TerminalColorScheme.charcoal.background))
            #expect(terminalView.nativeForegroundColor == NSColor(hexValue: TerminalColorScheme.charcoal.foreground))
            #expect(terminalView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        }
    }

    @Test func changingFontResizesExistingTerminalAndKeepsText() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let terminalView = makeTerminal(store: store)
        terminalView.feed(text: "Keep this output")
        let originalColumnCount = terminalView.getTerminal().cols

        store.setFontFamily(.menlo)
        store.setFontSize(22)

        #expect(terminalView.font.pointSize == 22)
        #expect(terminalView.font.fontName == "Menlo-Regular")
        #expect(terminalView.getTerminal().cols < originalColumnCount)
        terminalView.selectAll()
        #expect(terminalView.getSelection()?.contains("Keep this output") == true)
    }

    @Test func matchingTheAppRemovesOverrideAndRespondsToParentAppearance() throws {
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let store = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        parent.appearance = NSAppearance(named: .darkAqua)
        let terminalView = makeTerminal(store: store)
        parent.addSubview(terminalView)

        store.setMode(.light)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: TerminalColorScheme.paper.background))
        store.setMode(.matchApp)
        #expect(terminalView.appearance == nil)
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: TerminalColorScheme.charcoal.background))

        parent.appearance = NSAppearance(named: .aqua)
        // Deliver AppKit's appearance callback explicitly because this view is not in an onscreen window.
        terminalView.viewDidChangeEffectiveAppearance()
        #expect(terminalView.nativeBackgroundColor == NSColor(hexValue: TerminalColorScheme.paper.background))
    }

    private func makeTerminal(store: TerminalAppearanceStore) -> SelectableTerminalView {
        SelectableTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: store)
    }
}
