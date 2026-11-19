import CoreText
import Foundation

/// The line height Ghostty sizes a cell from, read from the font's tables as Ghostty's `Face.getMetrics` reads it:
/// the OS/2 typographic metrics when the font says to use them, or else `hhea`'s, the typographic ones, and the
/// Windows ones, the first that are set. CoreText's own metrics stand in when the font has no `hhea` table.
struct GhosttyFontVerticalMetrics {
    let lineHeight: Double

    init(font: CTFont) {
        let unitsPerEm =
            Self.table(font, "head").flatMap { $0.uint16(at: 18) }
            ?? Self.table(font, "bhed").flatMap { $0.uint16(at: 18) }
            ?? Int(CTFontGetUnitsPerEm(font))
        let pixelsPerUnit = Double(CTFontGetSize(font)) / Double(max(unitsPerEm, 1))
        guard let hhea = Self.table(font, "hhea"), hhea.count >= 36,
            let hheaAscent = hhea.int16(at: 4), let hheaDescent = hhea.int16(at: 6), let hheaLineGap = hhea.int16(at: 8)
        else {
            lineHeight = Double(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
            return
        }
        let unitsHeight: Int
        if let os2 = Self.table(font, "OS/2"), os2.count >= 78,
            let fsSelection = os2.uint16(at: 62), let typoAscent = os2.int16(at: 68), let typoDescent = os2.int16(at: 70),
            let typoLineGap = os2.int16(at: 72), let winAscent = os2.uint16(at: 74), let winDescent = os2.uint16(at: 76)
        {
            let usesTypoMetrics = fsSelection & (1 << 7) != 0
            if usesTypoMetrics {
                unitsHeight = typoAscent - typoDescent + typoLineGap
            } else if hheaAscent != 0 || hheaDescent != 0 {
                unitsHeight = hheaAscent - hheaDescent + hheaLineGap
            } else if typoAscent != 0 || typoDescent != 0 {
                unitsHeight = typoAscent - typoDescent + typoLineGap
            } else {
                unitsHeight = winAscent + winDescent
            }
        } else {
            unitsHeight = hheaAscent - hheaDescent + hheaLineGap
        }
        lineHeight = Double(unitsHeight) * pixelsPerUnit
    }

    private static func table(_ font: CTFont, _ tag: String) -> Data? {
        let code = tag.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return CTFontCopyTable(font, code, []) as Data?
    }
}

extension Data {
    fileprivate func uint16(at offset: Int) -> Int? {
        guard offset + 2 <= count else { return nil }
        let start = startIndex + offset
        return Int(self[start]) << 8 | Int(self[start + 1])
    }

    fileprivate func int16(at offset: Int) -> Int? {
        uint16(at: offset).map { Int(Int16(bitPattern: UInt16($0))) }
    }
}
