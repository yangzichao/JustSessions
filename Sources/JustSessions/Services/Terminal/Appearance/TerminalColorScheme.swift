import AppKit
import SwiftTerm

/// ANSI colors are tuned separately for paper and charcoal so colored text stays readable on either surface.
struct TerminalColorScheme {
    let background: UInt32
    let foreground: UInt32
    let selectionBackground: UInt32
    let selectionForeground: UInt32
    let ansiHexColors: [UInt32]

    static let paper = TerminalColorScheme(
        background: 0xFCFBF8,
        foreground: 0x303139,
        selectionBackground: 0xD9E4EF,
        selectionForeground: 0x202733,
        ansiHexColors: [
            0x303139, 0xB43C42, 0x327348, 0x8A631B,
            0x365FA6, 0x87509D, 0x237479, 0xB6B2AA,
            0x6C6C74, 0xBE3941, 0x277640, 0x886000,
            0x315FAF, 0x9146A4, 0x12747B, 0xFCFBF8,
        ]
    )

    static let charcoal = TerminalColorScheme(
        background: 0x1F1F23,
        foreground: 0xECEAE5,
        selectionBackground: 0x3C4B62,
        selectionForeground: 0xFFFFFF,
        ansiHexColors: [
            0x292A30, 0xE88287, 0x96C89C, 0xDEC084,
            0x94B3EA, 0xC8A0D9, 0x87C8C8, 0xD2D0CA,
            0x8F9099, 0xF19A9E, 0xAEDBB3, 0xEAD29D,
            0xADC7F3, 0xD9B6E7, 0xA2DADA, 0xFCFBF8,
        ]
    )

    var ansiColors: [SwiftTerm.Color] {
        ansiHexColors.map { hexValue in
            SwiftTerm.Color(
                red: UInt16((hexValue >> 16) & 0xFF) * 257,
                green: UInt16((hexValue >> 8) & 0xFF) * 257,
                blue: UInt16(hexValue & 0xFF) * 257
            )
        }
    }
}
