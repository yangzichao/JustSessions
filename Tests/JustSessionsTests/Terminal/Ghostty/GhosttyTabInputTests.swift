import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import JustSessions

/// What a Ghostty tab sends its process for keys, scrolling, and dropped files, compared with a SwiftTerm tab.
@MainActor
@Suite(.serialized)
struct GhosttyTabInputTests {
    // MARK: Shift-Return

    @Test func aTabInTmuxSendsShiftReturnAsCSIuAndReturnAsItself() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.sendsShiftReturnAsCSIu = true
        try await fixture.start(printing: "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }

        fixture.view.keyDown(with: returnKey(modifiers: .shift, window: fixture.window))
        fixture.view.keyDown(with: returnKey(modifiers: [], window: fixture.window))

        try await expectEventually { fixture.receivedInput.utf8.count >= 8 }
        #expect(fixture.receivedInput == "\u{1B}[13;2u\r")
    }

    /// Other tabs get Ghostty's own Shift-Return.
    @Test func otherTabsSendGhosttysShiftReturn() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }

        fixture.view.keyDown(with: returnKey(modifiers: .shift, window: fixture.window))

        try await expectEventually { !fixture.receivedInput.isEmpty }
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput == "\u{1B}[27;2;13~")
    }

    /// Shift-Return and the alternate screen's page keys go out in their place among the keys typed around them,
    /// which Ghostty sends from its IO thread.
    @Test func keysTheTabSendsItselfKeepTheirPlaceAmongTypedKeys() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.sendsShiftReturnAsCSIu = true
        try await fixture.start(printing: "printf '\\033[?1049hALTERNATE'")
        try await expectEventually { fixture.screen.contains("ALTERNATE") }
        let window = fixture.window
        let rounds = 50

        for _ in 0..<rounds {
            fixture.view.keyDown(with: SyntheticKey.event(keyCode: kVK_ANSI_A, characters: "a", window: window))
            fixture.view.keyDown(with: returnKey(modifiers: .shift, window: window))
            fixture.view.keyDown(with: SyntheticKey.event(keyCode: kVK_ANSI_B, characters: "b", window: window))
            fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        }

        let expected = String(repeating: "a\u{1B}[13;2ub\u{1B}[5~", count: rounds)
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(fixture.receivedInput == expected)
    }

    /// The tab sends those keys with Ghostty's `text:` action, which takes a Zig string literal and reports that it ran.
    @Test func ghosttysTextActionSendsTheTextAsGiven() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }
        let text = "\u{1B}[13;2u \\x1b \u{7F}\t\r\n\u{1}\"'\u{1B}[5~ \u{4F60}\u{597D}"
        #expect(GhosttyTabTerminalView.textAction(typing: ShiftReturnKey.csiUSequence) == "text:\\x1b[13;2u")

        #expect(fixture.view.performBindingAction(GhosttyTabTerminalView.textAction(typing: text)))

        try await expectEventually { fixture.receivedInput.utf8.count >= text.utf8.count }
        #expect(fixture.receivedInput == text)
    }

    // MARK: Page Up and Page Down

    /// On the main screen Page Up scrolls back a page and sends nothing; on the alternate screen it sends `CSI 5 ~`,
    /// with or without Shift, and Page Down `CSI 6 ~`; back on the main screen it scrolls again, as in SwiftTerm.
    @Test func pageKeysScrollTheMainScreenAndGoToAProgramOnTheAlternateScreen() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: """
            i=1; while [ $i -le 200 ]; do printf 'line-%03d\\r\\n' $i; i=$((i+1)); done
            wait_for alternate; printf '\\033[?1049hALTERNATE'
            wait_for main; printf '\\033[?1049lMAIN-AGAIN'
            """)
        try await expectEventually { fixture.screen.contains("line-200") }
        let window = fixture.window

        // Ghostty scrolls on its IO thread.
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        try await expectEventually { !fixture.screen.contains("line-200") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageDown, window: window))
        try await expectEventually { fixture.screen.contains("line-200") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, modifiers: .shift, window: window))
        try await expectEventually { !fixture.screen.contains("line-200") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageDown, modifiers: .shift, window: window))
        try await expectEventually { fixture.screen.contains("line-200") }
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput.isEmpty)

        fixture.signal("alternate")
        try await expectEventually { fixture.screen.contains("ALTERNATE") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, modifiers: .shift, window: window))
        fixture.view.keyDown(with: Self.pageKey(kVK_PageDown, window: window))
        fixture.view.keyDown(with: Self.pageKey(kVK_PageDown, modifiers: .shift, window: window))
        let alternateScreenKeys = "\u{1B}[5~\u{1B}[5~\u{1B}[6~\u{1B}[6~"
        try await expectEventually { fixture.receivedInput.utf8.count >= alternateScreenKeys.utf8.count }
        #expect(fixture.receivedInput == alternateScreenKeys)

        fixture.signal("main")
        try await expectEventually { fixture.screen.contains("MAIN-AGAIN") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        try await expectEventually { !fixture.screen.contains("MAIN-AGAIN") }
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput == alternateScreenKeys)
    }

    /// While a program has turned on the kitty keyboard protocol, a SwiftTerm tab sends the page keys encoded under it
    /// on either screen, so this tab leaves them to Ghostty, which sends them with Shift when held, and doesn't scroll.
    /// Once the program turns the protocol off, they scroll again.
    @Test func underTheKittyKeyboardProtocolPageKeysGoToTheProgramOnEitherScreen() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: """
            i=1; while [ $i -le 200 ]; do printf 'line-%03d\\r\\n' $i; i=$((i+1)); done; printf '\\033[>1uKITTY-MAIN'
            wait_for alternate; printf '\\033[?1049h\\033[>1uKITTY-ALTERNATE'
            wait_for main; printf '\\033[<u\\033[?1049l\\033[<uMAIN-AGAIN'
            """)
        try await expectEventually { fixture.screen.contains("KITTY-MAIN") }
        let window = fixture.window
        let keys = "\u{1B}[5~\u{1B}[5;2~\u{1B}[6~\u{1B}[6;2~"

        Self.pressEachPageKey(on: fixture.view, window: window)
        try await expectEventually { fixture.receivedInput.utf8.count >= keys.utf8.count }
        #expect(fixture.receivedInput == keys)
        #expect(fixture.screen.contains("KITTY-MAIN"), "The main screen scrolled")

        fixture.signal("alternate")
        try await expectEventually { fixture.screen.contains("KITTY-ALTERNATE") }
        Self.pressEachPageKey(on: fixture.view, window: window)
        try await expectEventually { fixture.receivedInput.utf8.count >= 2 * keys.utf8.count }
        #expect(fixture.receivedInput == keys + keys)

        fixture.signal("main")
        try await expectEventually { fixture.screen.contains("MAIN-AGAIN") }
        fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        try await expectEventually { !fixture.screen.contains("MAIN-AGAIN") }
        try await Task.sleep(for: .milliseconds(200))
        #expect(fixture.receivedInput == keys + keys)
    }

    /// Page Up and Page Down with Control, Option, or Command are left to Ghostty, which sends them with the
    /// modifier, on either screen.
    @Test func pageKeysWithControlOptionOrCommandGoToGhostty() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: """
            i=1; while [ $i -le 200 ]; do printf 'line-%03d\\r\\n' $i; i=$((i+1)); done; printf 'MAIN-SCREEN'
            """)
        try await expectEventually { fixture.screen.contains("MAIN-SCREEN") }
        let window = fixture.window

        for modifier: NSEvent.ModifierFlags in [.control, .option, .command] {
            fixture.view.keyDown(with: Self.pageKey(kVK_PageUp, modifiers: modifier, window: window))
            fixture.view.keyDown(with: Self.pageKey(kVK_PageDown, modifiers: modifier, window: window))
        }

        let keys = "\u{1B}[5;5~\u{1B}[6;5~\u{1B}[5;3~\u{1B}[6;3~\u{1B}[5;9~\u{1B}[6;9~"
        try await expectEventually { fixture.receivedInput.utf8.count >= keys.utf8.count }
        #expect(fixture.receivedInput == keys)
        #expect(fixture.screen.contains("MAIN-SCREEN"), "The main screen scrolled")
    }

    private static func pressEachPageKey(on view: GhosttyTabTerminalView, window: NSWindow) {
        view.keyDown(with: Self.pageKey(kVK_PageUp, window: window))
        view.keyDown(with: Self.pageKey(kVK_PageUp, modifiers: .shift, window: window))
        view.keyDown(with: Self.pageKey(kVK_PageDown, window: window))
        view.keyDown(with: Self.pageKey(kVK_PageDown, modifiers: .shift, window: window))
    }

    // MARK: Scrolling

    @Test func theScrollWheelScrollsBackThroughTheOutput() async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        try await fixture.start(printing: "i=1; while [ $i -le 200 ]; do printf 'line-%03d\\r\\n' $i; i=$((i+1)); done")
        try await expectEventually { fixture.screen.contains("line-200") }

        let firstLineBefore = try #require(Self.lineNumbers(on: fixture.screen).first)

        let scroll = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 10, wheel2: 0, wheel3: 0))
        fixture.view.scrollWheel(with: try #require(NSEvent(cgEvent: scroll)))

        try await expectEventually {
            let linesAfter = Self.lineNumbers(on: fixture.screen)
            return !linesAfter.contains(200) && (linesAfter.first ?? .max) < firstLineBefore
        }
    }

    /// The numbers of the `line-NNN` lines a screen shows, top to bottom.
    private static func lineNumbers(on screen: String) -> [Int] {
        screen.split(separator: "\n").compactMap { line in
            line.hasPrefix("line-") ? Int(line.dropFirst("line-".count).prefix(3)) : nil
        }
    }

    // MARK: Dropped files

    /// Each path goes as its own paste, as `TerminalFileDropPaste` gives it, marked as one when the program asked.
    @Test(arguments: [false, true])
    func droppedFilesTypeTheirPathsAsASwiftTermTabDoes(isBracketed: Bool) async throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.acceptsDroppedFiles = true
        try await fixture.start(printing: (isBracketed ? "printf '\\033[?2004h'; " : "") + "echo READY")
        try await expectEventually { fixture.screen.contains("READY") }
        var focusRequests = 0
        fixture.view.onFocus = { focusRequests += 1 }
        fixture.window.makeFirstResponder(nil)
        let paths = ["/tmp/My Folder/截图 1.png", "/tmp/it's (1).txt"]
        let drop = FileDrop(paths: paths)

        #expect(fixture.view.draggingEntered(drop) == .copy)
        #expect(fixture.view.performDragOperation(drop))

        let expected = String(decoding: TerminalFileDropPaste.bytes(forPaths: paths, isBracketed: isBracketed), as: UTF8.self)
        try await expectEventually { fixture.receivedInput.utf8.count >= expected.utf8.count }
        #expect(fixture.receivedInput == expected)
        #expect(focusRequests == 1)
        #expect(fixture.window.firstResponder === fixture.view)
    }

    @Test func aDragWithNoFilesIsRefused() throws {
        let fixture = try GhosttyTabFixture()
        defer { fixture.tearDown() }
        fixture.view.acceptsDroppedFiles = true
        let drop = FileDrop(paths: [])

        #expect(fixture.view.draggingEntered(drop) == [])
        #expect(!fixture.view.performDragOperation(drop))
    }

    /// Ghostty takes no paste before the terminal is in a window, which gives it a surface.
    @Test func aDropBeforeGhosttyCanTakeItIsRefused() {
        let view = GhosttyTabTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.acceptsDroppedFiles = true
        let drop = FileDrop(paths: ["/tmp/dropped.txt"])

        #expect(view.draggingEntered(drop) == .copy)
        #expect(!view.performDragOperation(drop))
    }

    @Test func turningDropsOnAndOffRegistersAndUnregistersTheTerminal() {
        let view = GhosttyTabTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        #expect(view.registeredDraggedTypes.isEmpty)

        view.acceptsDroppedFiles = true
        #expect(view.registeredDraggedTypes.contains(.fileURL))

        view.acceptsDroppedFiles = false
        #expect(view.registeredDraggedTypes.isEmpty)
    }

    private func returnKey(modifiers: NSEvent.ModifierFlags, window: NSWindow) -> NSEvent {
        SyntheticKey.event(keyCode: kVK_Return, characters: "\r", modifiers: modifiers, window: window)
    }

    /// Page Up and Page Down as a US keyboard sends them, the same as Fn-↑ and Fn-↓.
    private static func pageKey(_ keyCode: Int, modifiers: NSEvent.ModifierFlags = [], window: NSWindow) -> NSEvent {
        let character = keyCode == kVK_PageUp ? NSPageUpFunctionKey : NSPageDownFunctionKey
        return SyntheticKey.event(
            keyCode: keyCode,
            characters: String(UnicodeScalar(UInt16(character))!),
            modifiers: modifiers.union(.function),
            window: window
        )
    }
}

/// A drag of files onto the terminal, on a pasteboard of its own, which goes with it.
private final class FileDrop: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard

    @MainActor init(paths: [String]) {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        pasteboard.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        draggingPasteboard = pasteboard
    }

    deinit {
        draggingPasteboard.releaseGlobally()
    }

    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 0
    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func resetSpringLoading() {}
}
