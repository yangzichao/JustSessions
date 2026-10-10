import Testing
@testable import JustSessions

struct TerminalPageKeyModeScannerTests {
    // MARK: Alternate screen

    @Test(arguments: [1049, 1047, 47])
    func eachAlternateScreenModeSwitchesToItAndBack(mode: Int) {
        var scanner = TerminalPageKeyModeScanner()
        #expect(!scanner.isOnAlternateScreen)

        scanner.scan(bytes("text\u{1B}[?\(mode)hmore"))
        #expect(scanner.isOnAlternateScreen)

        scanner.scan(bytes("\u{1B}[?\(mode)l"))
        #expect(!scanner.isOnAlternateScreen)
    }

    @Test func aSequenceSplitAcrossReadsCounts() {
        var scanner = TerminalPageKeyModeScanner()
        for part in ["\u{1B}", "[", "?10", "49", "h"] { scanner.scan(bytes(part)) }
        #expect(scanner.isOnAlternateScreen)

        for part in ["\u{1B}[?1049", "l"] { scanner.scan(bytes(part)) }
        #expect(!scanner.isOnAlternateScreen)
    }

    @Test func aModeAmongOthersCounts() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[?25;1049h"))
        #expect(scanner.isOnAlternateScreen)
    }

    @Test func aResetGoesBackToTheMainScreen() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[?1049h"))
        scanner.scan(bytes("\u{1B}"))
        scanner.scan(bytes("c"))
        #expect(!scanner.isOnAlternateScreen)
    }

    @Test func otherModesAndSequencesLeaveTheScreen() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[?1049h"))
        let others = [
            "\u{1B}[?25l", "\u{1B}[?2004l", "\u{1B}[1049l", "\u{1B}[?10490l", "\u{1B}[?1049n", "c", "\u{1B}[c",
            "\u{1B}[>1049l", "\u{1B}[=1049l", "\u{1B}[<u",
        ]
        for other in others {
            scanner.scan(bytes(other))
            #expect(scanner.isOnAlternateScreen, "\(Array(other.utf8))")
        }
    }

    // MARK: Kitty keyboard flags

    @Test func pushingFlagsTurnsTheProtocolOnAndPoppingThemTurnsItOff() {
        var scanner = TerminalPageKeyModeScanner()
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[>1u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[<u"))
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    /// Each pop goes back to the flags before the push it undoes.
    @Test func popsUndoPushesInTurn() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[>1u\u{1B}[>0u"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[<1u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[>3u\u{1B}[>5u\u{1B}[<2u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[<1u"))
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    /// As in Ghostty: `CSI > u` pushes no flags, and a pop of eight or more clears them all, however many were pushed.
    @Test func theStackFollowsGhosttys() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[>1u\u{1B}[>u"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes(String(repeating: "\u{1B}[>1u", count: 9) + "\u{1B}[<7u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes(String(repeating: "\u{1B}[>1u", count: 9) + "\u{1B}[<8u"))
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    @Test func settingFlagsReplacesAddsOrRemovesThem() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[=1u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[=0;1u"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[=8;2u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[=1;2u\u{1B}[=8;3u"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[=1;3u"))
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    /// As in Ghostty's parser, a `;` at the end adds no parameter: `CSI > 1 ; u` pushes 1, and `CSI = 1 ; u` sets 1.
    @Test func aSeparatorAtTheEndAddsNoParameter() {
        var pushing = TerminalPageKeyModeScanner()
        pushing.scan(bytes("\u{1B}[>1;u"))
        #expect(pushing.hasKittyKeyboardFlags)

        var setting = TerminalPageKeyModeScanner()
        setting.scan(bytes("\u{1B}[=1;u"))
        #expect(setting.hasKittyKeyboardFlags)

        var popping = TerminalPageKeyModeScanner()
        popping.scan(bytes("\u{1B}[>1u\u{1B}[>1u\u{1B}[<2;u"))
        #expect(!popping.hasKittyKeyboardFlags)
    }

    /// Ghostty ignores flags above five bits and a set mode other than 1, 2, or 3.
    @Test func sequencesGhosttyRejectsChangeNothing() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[>33u\u{1B}[=33u\u{1B}[=1;4u\u{1B}[=1;0u"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[>1u\u{1B}[=0;4u\u{1B}[<0u"))
        #expect(scanner.hasKittyKeyboardFlags)
    }

    /// Each screen keeps its own flags, as in Ghostty and SwiftTerm.
    @Test func eachScreenKeepsItsOwnFlags() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[>1u\u{1B}[?1049h"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[>1u\u{1B}[?1049l"))
        #expect(scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[<u"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[?1049h"))
        #expect(scanner.hasKittyKeyboardFlags)
    }

    @Test func aResetClearsBothScreensFlags() {
        var scanner = TerminalPageKeyModeScanner()
        scanner.scan(bytes("\u{1B}[>1u\u{1B}[?1049h\u{1B}[>1u\u{1B}c"))
        #expect(!scanner.hasKittyKeyboardFlags)

        scanner.scan(bytes("\u{1B}[?1049h"))
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    @Test func aKittySequenceSplitAcrossReadsCounts() {
        var scanner = TerminalPageKeyModeScanner()
        for part in ["\u{1B}", "[", ">", "1", "u"] { scanner.scan(bytes(part)) }
        #expect(scanner.hasKittyKeyboardFlags)

        for part in ["\u{1B}[=", "0;", "1", "u"] { scanner.scan(bytes(part)) }
        #expect(!scanner.hasKittyKeyboardFlags)
    }

    /// Other `u` sequences, a flags query, and modifyOtherKeys leave the flags as they are.
    @Test func otherSequencesLeaveTheFlags() {
        var scanner = TerminalPageKeyModeScanner()
        for other in ["\u{1B}[u", "\u{1B}[1u", "\u{1B}[?u", "\u{1B}[?1u", "\u{1B}[>4;1m", "\u{1B}[>1c", ">1u", "\u{1B}>1u"] {
            scanner.scan(bytes(other))
            #expect(!scanner.hasKittyKeyboardFlags, "\(Array(other.utf8))")
        }
    }

    private func bytes(_ text: String) -> ArraySlice<UInt8> {
        Array(text.utf8)[...]
    }
}
