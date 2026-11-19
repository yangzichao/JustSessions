import AppKit
import GhosttyTerminal
import Testing

@testable import JustSessions

/// The same output in a Ghostty and a SwiftTerm terminal with the same appearance settings: cells of the same size, and
/// text as large and as thick.
@MainActor
@Suite(.serialized)
struct GhosttyTextMatchesSwiftTermTests {
    private static let frame = NSRect(x: 0, y: 0, width: 600, height: 120)
    private static let hideCursor = "\u{1B}[?25l"
    /// See `TestMachine.isVirtual`.
    private static let drawnTextNeedsAMac: Comment = "Compares drawn text, which a virtual machine's GPU draws in other colors"

    @Test(arguments: [TerminalFontFamily.system, .named("Menlo"), .named("Courier New"), .named("PT Mono")], [10.0, 13, 17.5, 24])
    func cellsAreAsLargeAsSwiftTerms(_ family: TerminalFontFamily, _ size: Double) async throws {
        try await Self.expectCellsAsLargeAsSwiftTerms(family, size)
    }

    /// BIZ UDGothic names no glyph W; both engines size its cells by its glyph for W.
    @Test(.enabled(if: BIZUDGothicFont.isInstalled, BIZUDGothicFont.needsTheFont), arguments: [13.0, 17.5])
    func cellsAreAsLargeAsSwiftTermsInAFontThatNamesNoGlyphW(_ size: Double) async throws {
        try await Self.expectCellsAsLargeAsSwiftTerms(.named(BIZUDGothicFont.family), size)
    }

    private static func expectCellsAsLargeAsSwiftTerms(
        _ family: TerminalFontFamily, _ size: Double, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.appearance.setFontFamily(family)
        stores.appearance.setFontSize(size)
        let swiftTerm = SwiftTermTestTerminal(stores: stores, frame: Self.frame)
        let ghostty = Self.ghosttyTerminal(stores: stores, backingScaleFactor: swiftTerm.window.backingScaleFactor)
        let recorder = GridMetricsRecorder()
        ghostty.view.delegate = recorder
        ghostty.show("x")
        // A new size makes the terminal report its grid to the delegate it now has.
        ghostty.view.frame = Self.frame.insetBy(dx: 0, dy: 10)

        try await expectEventually({ recorder.metrics != nil }, sourceLocation: sourceLocation)
        let metrics = try #require(recorder.metrics, sourceLocation: sourceLocation)
        let ghosttyCell = TerminalCellPixelSize(width: Int(metrics.cellWidthPixels), height: Int(metrics.cellHeightPixels))
        #expect(ghosttyCell == swiftTerm.cellPixelSize, "\(family) at \(size) points", sourceLocation: sourceLocation)
    }

    /// Ghostty's own fallback would draw Chinese larger than SwiftTerm does, and bold Chinese in the regular weight or
    /// in PingFang's Bold rather than its Semibold.
    @Test(.enabled(if: !TestMachine.isVirtual, Self.drawnTextNeedsAMac))
    func chineseIsAsLargeAndAsBoldAsInSwiftTerm() async throws {
        let output = Self.hideCursor + "中文字体测试，标点。\r\n\u{1B}[1m粗体中文\u{1B}[0m"
        let (swiftTerm, ghostty) = try await Self.drawnLines(of: output, lineCount: 2, mode: .light)

        for line in 0..<2 {
            #expect(abs(ghostty.height(ofLine: line) - swiftTerm.height(ofLine: line)) <= 1, "line \(line)")
            Self.expectInk(of: ghostty, line: line, near: swiftTerm)
        }
    }

    /// SwiftTerm's font smoothing thickens light text more than dark text, so each is compared on its own. Bold text is
    /// SF Mono's Semibold, where Ghostty would pick its Bold.
    @Test(.enabled(if: !TestMachine.isVirtual, Self.drawnTextNeedsAMac), arguments: [TerminalAppearanceMode.light, .dark])
    func strokesAreAsThickAsSwiftTerms(_ mode: TerminalAppearanceMode) async throws {
        let (swiftTerm, ghostty) = try await Self.drawnLines(of: Self.styledLines, lineCount: 4, mode: mode)

        for line in 0..<4 {
            Self.expectInk(of: ghostty, line: line, near: swiftTerm)
        }
    }

    /// Monaco has no bold face, which SwiftTerm draws bold text in Monaco's regular face for, where Ghostty would
    /// embolden it.
    @Test(.enabled(if: !TestMachine.isVirtual, Self.drawnTextNeedsAMac))
    func boldTextInAFontWithoutABoldFaceIsAsThickAsInSwiftTerm() async throws {
        let (swiftTerm, ghostty) = try await Self.drawnLines(of: Self.styledLines, lineCount: 4, mode: .light, fontFamily: .named("Monaco"))

        for line in 0..<4 {
            Self.expectInk(of: ghostty, line: line, near: swiftTerm)
        }
    }

    /// Regular, bold, italic, and bold italic.
    private static let styledLines =
        hideCursor
        + ["", "1", "3", "1;3"]
        .map { "\u{1B}[\($0)mHello, world: abcdefghij 0123456789 {}[]\u{1B}[0m" }
        .joined(separator: "\r\n")

    /// Within 5%: without the matching, Ghostty's text was 13% lighter and its Chinese 14% heavier.
    private static func expectInk(
        of ghostty: DrawnTextLines, line: Int, near swiftTerm: DrawnTextLines, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let ratio = ghostty.ink(ofLine: line) / swiftTerm.ink(ofLine: line)
        #expect(abs(ratio - 1) < 0.05, "line \(line): Ghostty draws \(ratio)× SwiftTerm's ink", sourceLocation: sourceLocation)
    }

    private static func drawnLines(
        of output: String, lineCount: Int, mode: TerminalAppearanceMode, fontFamily: TerminalFontFamily = .system
    ) async throws -> (swiftTerm: DrawnTextLines, ghostty: DrawnTextLines) {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        stores.appearance.setMode(mode)
        stores.appearance.setFontFamily(fontFamily)
        let swiftTerm = SwiftTermTestTerminal(stores: stores, frame: frame)
        swiftTerm.show(output)
        let swiftTermLines = DrawnTextLines(try #require(swiftTerm.snapshot()))
        try #require(swiftTermLines.lines.count == lineCount)

        let ghostty = ghosttyTerminal(stores: stores, backingScaleFactor: swiftTerm.window.backingScaleFactor, mode: mode)
        ghostty.show(output)
        var ghosttyLines: DrawnTextLines?
        try await expectEventually {
            guard let bitmap = ghostty.view.snapshotImage()?.representations.first as? NSBitmapImageRep else { return false }
            ghosttyLines = DrawnTextLines(bitmap)
            return ghosttyLines?.lines.count == lineCount
        }
        return (swiftTermLines, try #require(ghosttyLines))
    }

    /// A terminal whose cells are sized for its window's screen. The shared controllers size them for the sharpest
    /// screen, which the window may not be on.
    private static func ghosttyTerminal(
        stores: IsolatedAppearanceStores, backingScaleFactor: CGFloat, mode: TerminalAppearanceMode = .light
    ) -> GhosttyTestTerminal {
        let configuration = GhosttyAppearanceConfiguration(
            preferences: stores.appearance.preferences, appTheme: stores.theme.terminalTheme, backingScaleFactor: backingScaleFactor
        )
        let controller = TerminalController(
            configSource: .generated("# JustSessions test"),
            theme: configuration.theme,
            terminalConfiguration: configuration.terminalConfiguration
        )
        let terminal = GhosttyTestTerminal(controller: controller, appearance: mode == .dark ? .darkAqua : .aqua, frame: frame)
        #expect(controller.lastConfigurationIssue == nil)
        #expect(terminal.window.backingScaleFactor == backingScaleFactor)
        return terminal
    }
}
