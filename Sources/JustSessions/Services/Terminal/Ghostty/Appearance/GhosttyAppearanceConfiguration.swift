import AppKit
import GhosttyTerminal

@MainActor
struct GhosttyAppearanceConfiguration {
    let terminalConfiguration: TerminalConfiguration
    let theme: TerminalTheme

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
            builder.withBoldColor("bright")
            builder.withWindowPaddingX(GhosttyZeroPaddingCellGrid.windowPadding)
            builder.withWindowPaddingY(GhosttyZeroPaddingCellGrid.windowPadding)
            builder.withCursorStyle(.block)
            builder.withCursorStyleBlink(true)
            builder.withCustom("macos-option-as-alt", optionIsMeta ? "true" : "false")
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

    private static let swiftTermKeybinds =
        TerminalEditingKey.allCases.map { editingKey in
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
