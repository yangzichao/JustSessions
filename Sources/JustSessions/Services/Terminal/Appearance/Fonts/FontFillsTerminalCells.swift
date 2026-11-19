import CoreText

/// Whether a font's letters fill a terminal's cells. SwiftTerm makes each cell as wide as the font's W, and Ghostty's
/// cells are adjusted to the same width; see `SwiftTermCellWidth` and `TerminalCellPixelSize`. Some fonts that call
/// themselves monospaced, mostly Japanese, Chinese, and Korean ones such as Osaka and Lantinghei TC, have letters of
/// different widths. In both engines their text spreads across the terminal with gaps between letters, and lines break
/// early or overlap.
///
/// Core Text is thread-safe, so this can run off the main thread.
enum FontFillsTerminalCells {
    private static let widthTolerance: CGFloat = 0.02

    static func check(_ font: CTFont) -> Bool {
        let cellWidth = SwiftTermCellWidth.advance(of: font)
        guard cellWidth > 0 else { return false }

        let characters = (32..<127).map { UniChar($0) }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else { return false }
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        return advances.allSatisfy { abs($0.width - cellWidth) <= cellWidth * widthTolerance }
    }
}
