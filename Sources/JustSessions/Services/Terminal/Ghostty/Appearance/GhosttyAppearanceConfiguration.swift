import AppKit
import GhosttyTerminal

/// The terminal appearance settings as Ghostty configuration, so a Ghostty terminal looks and behaves like a SwiftTerm
/// terminal styled by `TerminalAppearanceStyling`. Colors, and how strongly text in them is thickened, go in the theme,
/// in a light and a dark version: the terminal view switches its controller between them from its own appearance,
/// which `TerminalAppearanceStyling.nativeAppearance` sets, so the Appearance setting needs nothing here. Everything
/// else goes in the terminal configuration; the font keys come from `GhosttyFontConfiguration`.
@MainActor
struct GhosttyAppearanceConfiguration {
    let terminalConfiguration: TerminalConfiguration
    let theme: TerminalTheme

    /// `ghosttyFindsFontFamily` stands in for Ghostty's font lookup, `GhosttyFontConfiguration.fontDiscoveryFinds`, in
    /// tests. The cells are sized for a screen of `backingScaleFactor`. `optionIsMeta` is `TerminalOptionKeyStore`'s.
    init(
        preferences: TerminalAppearancePreferences,
        appTheme: ResolvedAppTheme,
        optionIsMeta: Bool = TerminalOptionKeyStore.defaultOptionIsMeta,
        backingScaleFactor: CGFloat = GhosttyFontConfiguration.screensBackingScaleFactor,
        ghosttyFindsFontFamily: (String) -> Bool = GhosttyFontConfiguration.fontDiscoveryFinds(family:)
    ) {
        let preferences = preferences.validated
        terminalConfiguration = Self.terminalConfiguration(
            for: preferences, optionIsMeta: optionIsMeta, backingScaleFactor: backingScaleFactor,
            ghosttyFindsFontFamily: ghosttyFindsFontFamily
        )
        let variants = preferences.colorVariants(appTheme: appTheme)
        theme = TerminalTheme(
            light: Self.colors(variants.palette(usesDarkColors: false)),
            dark: Self.colors(variants.palette(usesDarkColors: true))
        )
    }

    /// Built from empty rather than from `TerminalConfiguration.default`, which thickens the font at full strength
    /// whatever the colors. Ghostty rejects a whole configuration over one unknown key or value, so each key here is
    /// one Ghostty knows.
    private static func terminalConfiguration(
        for preferences: TerminalAppearancePreferences,
        optionIsMeta: Bool,
        backingScaleFactor: CGFloat,
        ghosttyFindsFontFamily: (String) -> Bool
    ) -> TerminalConfiguration {
        TerminalConfiguration { builder in
            GhosttyFontConfiguration.add(
                to: &builder, preferences: preferences, backingScaleFactor: backingScaleFactor,
                ghosttyFindsFontFamily: ghosttyFindsFontFamily
            )
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
            // As SwiftTerm's `optionAsMetaKey`: Option is Meta whatever the keyboard layout, or types the layout's
            // characters. Option-Left and Option-Right keep their bindings below either way.
            builder.withCustom("macos-option-as-alt", optionIsMeta ? "true" : "false")
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

    /// Keys Ghostty would otherwise send differently from a SwiftTerm terminal.
    /// - Command-Left, Command-Right, Command-Delete, and Command-Z send `TerminalEditingKey`'s control keys. Ghostty
    ///   would send the arrows with Command, as `CSI 1;9 D`, and DEL for Command-Delete. The view takes a key bound here
    ///   before the app's menus, so Edit → Undo doesn't take Command-Z.
    /// - Option-Left sends Esc b, and Option-Right Esc f, which move a shell's cursor a word back or forward. Ghostty
    ///   would send them with Option, as `CSI 1;3 D`.
    /// - Command-Up and Command-Down send nothing, since SwiftTerm handles neither of the commands macOS gives them.
    ///   Ghostty would send `CSI 1;9 A` and `CSI 1;9 B`.
    /// Page Up and Page Down stay unbound: SwiftTerm scrolls with them on the main screen but sends them to the program
    /// on the alternate screen, and a Ghostty binding would take them on both.
    private static let swiftTermKeybinds = TerminalEditingKey.allCases.map { editingKey in
        "\(editingKey.ghosttyTrigger)=\(GhosttyTabTerminalView.textAction(typing: editingKey.controlCharacter))"
    } + [
        "alt+arrow_left=esc:b",
        "alt+arrow_right=esc:f",
        "super+arrow_up=ignore",
        "super+arrow_down=ignore",
    ]

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
            builder.withFontThickenStrength(GhosttyFontConfiguration.thickenStrength(drawing: scheme.foreground))
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
