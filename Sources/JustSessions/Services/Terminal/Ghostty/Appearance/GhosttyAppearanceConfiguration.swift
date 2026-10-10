import AppKit
import CoreText
import GhosttyTerminal

/// The terminal appearance settings as Ghostty configuration, so a Ghostty terminal looks and behaves like a SwiftTerm
/// terminal styled by `TerminalAppearanceStyling`. Colors go in the theme, in a light and a dark version: the terminal
/// view switches its controller between them from its own appearance, which `TerminalAppearanceStyling.nativeAppearance`
/// sets, so the Appearance setting needs nothing here. Everything else goes in the terminal configuration.
@MainActor
struct GhosttyAppearanceConfiguration {
    let terminalConfiguration: TerminalConfiguration
    let theme: TerminalTheme

    /// `ghosttyFindsFontFamily` stands in for Ghostty's font lookup, `fontDiscoveryFinds(family:)`, in tests.
    init(
        preferences: TerminalAppearancePreferences,
        appTheme: ResolvedAppTheme,
        ghosttyFindsFontFamily: (String) -> Bool = GhosttyAppearanceConfiguration.fontDiscoveryFinds(family:)
    ) {
        let preferences = preferences.validated
        terminalConfiguration = Self.terminalConfiguration(for: preferences, ghosttyFindsFontFamily: ghosttyFindsFontFamily)
        let variants = preferences.colorVariants(appTheme: appTheme)
        theme = TerminalTheme(
            light: Self.colors(variants.palette(usesDarkColors: false)),
            dark: Self.colors(variants.palette(usesDarkColors: true))
        )
    }

    /// Built from empty rather than from `TerminalConfiguration.default`, which thickens the font. Ghostty rejects a
    /// whole configuration over one unknown key or value, so each key here is one Ghostty knows.
    private static func terminalConfiguration(
        for preferences: TerminalAppearancePreferences,
        ghosttyFindsFontFamily: (String) -> Bool
    ) -> TerminalConfiguration {
        TerminalConfiguration { builder in
            builder.withFontFamily(fontFamily(preferences.fontFamily, size: preferences.fontSize, ghosttyFinds: ghosttyFindsFontFamily))
            builder.withFontSize(Float(preferences.fontSize))
            builder.withMinimumContrast(Double(TerminalAppearanceStyling.minimumContrastRatio))
            // SwiftTerm draws bold text in ANSI colors 0–6 in their bright versions, 8–14 (its `useBrightColors`).
            // Ghostty does the same for 0–7, so unlike SwiftTerm it also draws bold white (7) as bright white (15).
            builder.withBoldColor("bright")
            // The app's inset view draws the terminal's margins.
            builder.withWindowPaddingX(0)
            builder.withWindowPaddingY(0)
            // SwiftTerm's caret is a blinking block.
            builder.withCursorStyle(.block)
            builder.withCursorStyleBlink(true)
            // SwiftTerm sends Option as Meta (its `optionAsMetaKey` is true) whatever the keyboard layout.
            builder.withCustom("macos-option-as-alt", "true")
            // SwiftTerm pastes without asking and lets programs read and write the clipboard with OSC 52.
            builder.withCustom("clipboard-paste-protection", "false")
            builder.withCustom("clipboard-read", "allow")
            builder.withCustom("clipboard-write", "allow")
            // Ghostty's own shortcuts, such as Command-W to close and Command-T for a new tab, would take the app's.
            // Copy, Paste, and Select All still work: the Edit menu calls the view's actions, which run Ghostty's
            // actions directly rather than through a shortcut.
            builder.withCustom("keybind", "clear")
            for keybind in swiftTermKeybinds {
                builder.withCustom("keybind", keybind)
            }
        }
    }

    /// Keys Ghostty would otherwise send differently from a SwiftTerm terminal. No app menu uses them.
    /// - Command-Left and Option-Left send Esc b, and Command-Right and Option-Right Esc f, which move a shell's cursor
    ///   a word back or forward. Ghostty would send them with modifiers, as `CSI 1;9 D` and `CSI 1;3 D`.
    /// - Command-Delete, Command-Up, and Command-Down send nothing, since SwiftTerm handles none of the commands macOS
    ///   gives them. Ghostty would send DEL, and `CSI 1;9 A` and `CSI 1;9 B`.
    /// Page Up and Page Down stay unbound: SwiftTerm scrolls with them on the main screen but sends them to the program
    /// on the alternate screen, and a Ghostty binding would take them on both.
    private static let swiftTermKeybinds = [
        "super+arrow_left=esc:b",
        "super+arrow_right=esc:f",
        "alt+arrow_left=esc:b",
        "alt+arrow_right=esc:f",
        "super+backspace=ignore",
        "super+arrow_up=ignore",
        "super+arrow_down=ignore",
    ]

    /// The family of the font a SwiftTerm terminal would draw with. System Monospaced is SF Mono under its hidden
    /// family name, `.AppleSystemUIFontMonospaced`, which Ghostty's font discovery finds. A named family that is no
    /// longer installed gives the system font, as it does in SwiftTerm. A family Ghostty can't find gives Menlo,
    /// rather than Ghostty's built-in JetBrains Mono, whose cells are a different size.
    private static func fontFamily(_ fontFamily: TerminalFontFamily, size: Double, ghosttyFinds: (String) -> Bool) -> String {
        let font = fontFamily.font(size: CGFloat(size))
        let family = font.familyName ?? font.fontName
        guard !ghosttyFinds(family), ghosttyFinds(fallbackFontFamily) else { return family }
        return fallbackFontFamily
    }

    private static let fallbackFontFamily = "Menlo"

    /// Whether Ghostty's font discovery finds faces of `family`: it asks Core Text for a collection of the fonts whose
    /// family name is `family`.
    nonisolated static func fontDiscoveryFinds(family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let collection = CTFontCollectionCreateWithFontDescriptors([descriptor] as CFArray, nil)
        let matches = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] ?? []
        return !matches.isEmpty
    }

    private static func colors(_ palette: TerminalPalette) -> TerminalConfiguration {
        let scheme = palette.scheme
        return TerminalConfiguration { builder in
            builder.withBackground(hex(palette.background))
            builder.withForeground(hex(scheme.foreground))
            builder.withSelectionBackground(hex(scheme.selectionBackground))
            // Ghostty, like SwiftTerm, draws selected text in this one color without its minimum contrast, so it takes
            // the readable version `TerminalAppearanceStyling` gives SwiftTerm.
            builder.withSelectionForeground(hex(scheme.readableSelectionForeground))
            builder.withCursorColor(hex(scheme.foreground))
            builder.withCursorText(hex(palette.background))
            // The colors SwiftTerm draws with too, each kept apart from the background. Like SwiftTerm, which ignores a
            // set of other than 16 colors; Ghostty rejects the whole configuration over an index past 255.
            let ansiColors = palette.distinguishableANSIHexColors
            if ansiColors.count == 16 {
                for (index, color) in ansiColors.enumerated() {
                    builder.withPalette(index, color: hex(color))
                }
            }
        }
    }

    private static func hex(_ color: UInt32) -> String {
        String(format: "#%06X", color & 0xFFFFFF)
    }
}
