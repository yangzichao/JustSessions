import AppKit
import CoreText
import Testing

@testable import JustSessions

@MainActor
struct TerminalCellPixelSizeTests {
    /// STHeiti ships with macOS and, as BIZ UDGothic and PCMyungjo, names no glyph W. Its glyph named W would be
    /// `.notdef`, a full em wide, but SwiftTerm and the size Ghostty's cells are adjusted to take its W. Its W is 0.96
    /// em wide, so at 48 points its cells are at least a pixel narrower than an em on a 1x screen, such as the release
    /// runner's, as well as on a Retina one.
    @Test func swiftTermsCellsAreAsWideAsWInAFontThatNamesNoGlyphW() throws {
        let font = try #require(NSFont(name: "STHeitiSC-Light", size: 48))
        #expect(CTFontGetGlyphWithName(font, "W" as CFString) == 0)
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let swiftTerm = SwiftTermTestTerminal(stores: stores, frame: NSRect(x: 0, y: 0, width: 600, height: 200))
        swiftTerm.view.font = font
        let backingScaleFactor = swiftTerm.window.backingScaleFactor

        let cell = TerminalCellPixelSize.swiftTerm(font: font, backingScaleFactor: backingScaleFactor)
        #expect(swiftTerm.cellPixelSize == cell)
        #expect(CGFloat(cell.width) < font.pointSize * backingScaleFactor)
    }
}
