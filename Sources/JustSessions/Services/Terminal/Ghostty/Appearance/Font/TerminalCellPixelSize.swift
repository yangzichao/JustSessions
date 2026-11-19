import AppKit
import CoreText

struct TerminalCellPixelSize: Equatable {
    var width: Int
    var height: Int

    /// SwiftTerm's `computeFontDimensions`: the advance of W, see `SwiftTermCellWidth`, rounded to the nearest pixel, and
    /// the line height rounded up to whole points, then up to whole pixels.
    static func swiftTerm(font: NSFont, backingScaleFactor: CGFloat) -> Self {
        let ctFont = font as CTFont
        let lineHeight = ceil(CTFontGetAscent(ctFont) + CTFontGetDescent(ctFont) + CTFontGetLeading(ctFont))
        let advance = SwiftTermCellWidth.advance(of: ctFont)
        return Self(width: Int((advance * backingScaleFactor).rounded()), height: Int(ceil(lineHeight * backingScaleFactor)))
    }

    /// Ghostty's `Metrics.calc`, for the face Ghostty finds for `family` at `pointSize`: the widest advance of the
    /// printable ASCII characters and the line height from the font's tables, at the font's size in pixels, each
    /// rounded to the nearest pixel.
    static func ghostty(family: String, pointSize: CGFloat, backingScaleFactor: CGFloat) -> Self {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, pointSize * backingScaleFactor, nil)
        let characters = (32..<127).map { UniChar($0) }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        let widestAdvance = advances.map(\.width).max() ?? 0
        let lineHeight = GhosttyFontVerticalMetrics(font: font).lineHeight
        return Self(width: Int(widestAdvance.rounded()), height: Int(lineHeight.rounded()))
    }
}
