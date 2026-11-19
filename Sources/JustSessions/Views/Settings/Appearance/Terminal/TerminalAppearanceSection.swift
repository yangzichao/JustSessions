import SwiftUI

/// The terminal part of the Appearance tab: the engine new tabs open with, what the Option key does, the color scheme, which matches the app
/// theme unless set here, its light or dark version, how strongly its colors show, the font, and a preview. Rows of
/// the tab's grid.
struct TerminalAppearanceSection: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    @ObservedObject var engineStore: TerminalEngineStore
    @ObservedObject var optionKeyStore: TerminalOptionKeyStore
    /// For the preview, which can show the theme's terminal colors.
    let themeStore: AppThemeStore

    var body: some View {
        GridRow {
            SettingsSectionHeading("Terminal") {
                Button("Restore Defaults") { appearanceStore.restoreDefaults() }
                    .buttonStyle(QuietBorderedButtonStyle())
                    .controlSize(.small)
                    .disabled(appearanceStore.preferences == TerminalAppearancePreferences())
                    .help("Restores the terminal colors, font, and size.")
            }
        }
        GridRow {
            Text("Engine")
            HStack(spacing: 4) {
                ThemeSegmentedPicker(
                    "Engine",
                    selection: Binding(
                        get: { engineStore.engine },
                        set: { engineStore.setEngine($0) }
                    ),
                    segments: TerminalEngine.allCases.map { engine in
                        ThemeSegment(value: engine, title: Text(verbatim: engine.displayName))
                    }
                )
                .fixedSize()
                HelpPopoverButton(
                    title: "Terminal engine",
                    explanation: "Applies to tabs opened after you change it."
                )
                .accessibilityIdentifier("settings.help.terminalEngine")
            }
        }
        GridRow {
            Text("Option key")
            HStack(spacing: 4) {
                Toggle(
                    "Use Option as Meta",
                    isOn: Binding(
                        get: { optionKeyStore.optionIsMeta },
                        set: { optionKeyStore.setOptionIsMeta($0) }
                    )
                )
                .toggleStyle(ThemedCheckboxToggleStyle())
                .accessibilityIdentifier("settings.optionIsMeta")
                HelpPopoverButton(
                    title: "Option key",
                    explanation:
                        "Option with a key sends Esc and that key, which shells and CLIs read as Alt shortcuts. Turn it off to type the characters your keyboard layout keeps behind Option, such as brackets, braces, or the pipe. Open tabs follow the change."
                )
                .accessibilityIdentifier("settings.help.optionKey")
            }
        }
        GridRow {
            Text("Colors")
            TerminalColorSchemePicker(appearanceStore: appearanceStore)
        }
        GridRow {
            Text("Light or dark")
            ThemeSegmentedPicker(
                "Light or dark",
                selection: Binding(
                    get: { appearanceStore.preferences.mode },
                    set: { appearanceStore.setMode($0) }
                ),
                segments: TerminalAppearanceMode.allCases.map { mode in
                    ThemeSegment(value: mode, title: Text(mode.localizedDisplayName))
                }
            )
            // The theme only matters here for whether the scheme has both versions, and every app theme does.
            .disabled(!appearanceStore.preferences.colorVariants(appTheme: themeStore.resolvedTheme).hasLightAndDarkVersions)
            .help("Picks the light or dark version of color schemes that have both.")
        }
        GridRow {
            Text("Color intensity")
            TerminalColorIntensitySlider(appearanceStore: appearanceStore)
        }
        GridRow {
            Text("Font")
            TerminalFontPicker(appearanceStore: appearanceStore)
        }
        GridRow {
            Text("Size")
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { appearanceStore.preferences.fontSize },
                        set: { appearanceStore.setFontSize($0) }
                    ), in: TerminalAppearancePreferences.fontSizeRange, step: 1
                )
                .accessibilityLabel("Font size")
                Text("\(Int(appearanceStore.preferences.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
        }
        GridRow(alignment: .top) {
            Text("Preview")
            TerminalAppearancePreview(engine: engineStore.engine, appearanceStore: appearanceStore, themeStore: themeStore)
                // A new terminal, drawn by the newly chosen engine.
                .id(engineStore.engine)
                // A fixed height, so a bigger font shows fewer lines instead of making the tab taller.
                .frame(height: 130)
                .clipShape(RoundedRectangle(.card))
                .overlay(RoundedRectangle(.card).strokeBorder(ThemePalette.hairline))
                .allowsHitTesting(false)
                .accessibilityLabel("Terminal appearance preview")
        }
    }
}
