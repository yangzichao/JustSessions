import SwiftUI

/// The terminal part of the Appearance tab: the color scheme, which matches the app theme unless set here, its light
/// or dark version, the font, and a preview. Rows of the tab's grid.
struct TerminalAppearanceSection: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    /// For the preview, which can show the theme's terminal colors.
    let themeStore: AppThemeStore

    var body: some View {
        GridRow {
            SettingsSectionHeading("Terminal") {
                Button("Restore Defaults") { appearanceStore.restoreDefaults() }
                    .controlSize(.small)
                    .disabled(appearanceStore.preferences == TerminalAppearancePreferences())
                    .help("Restores the terminal colors, font, and size.")
            }
        }
        GridRow {
            Text("Colors")
            TerminalColorSchemePicker(appearanceStore: appearanceStore)
        }
        GridRow {
            Text("Light or dark")
            Picker("Light or dark", selection: Binding(
                get: { appearanceStore.preferences.mode },
                set: { appearanceStore.setMode($0) }
            )) {
                ForEach(TerminalAppearanceMode.allCases) { mode in
                    Text(mode.localizedDisplayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // The theme only matters here for whether the scheme has both versions, and every app theme does.
            .disabled(!appearanceStore.preferences.colorVariants(appTheme: themeStore.theme).hasLightAndDarkVersions)
            .help("Picks the light or dark version of color schemes that have both.")
        }
        GridRow {
            Text("Font")
            Picker("Font", selection: Binding(
                get: { appearanceStore.preferences.fontFamily },
                set: { appearanceStore.setFontFamily($0) }
            )) {
                ForEach(TerminalFontFamily.allCases) { family in
                    if family == .system {
                        Text("System Monospaced").tag(family)
                    } else {
                        Text(verbatim: family.displayName).tag(family)
                    }
                }
            }
            .labelsHidden()
        }
        GridRow {
            Text("Size")
            HStack(spacing: 12) {
                Slider(value: Binding(
                    get: { appearanceStore.preferences.fontSize },
                    set: { appearanceStore.setFontSize($0) }
                ), in: TerminalAppearancePreferences.fontSizeRange, step: 1)
                .accessibilityLabel("Font size")
                Text("\(Int(appearanceStore.preferences.fontSize)) pt")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
        }
        GridRow(alignment: .top) {
            Text("Preview")
            VStack(alignment: .leading, spacing: 6) {
                TerminalAppearancePreview(appearanceStore: appearanceStore, themeStore: themeStore)
                    // A fixed height, so a bigger font shows fewer lines instead of making the tab taller.
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThemePalette.hairline))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Terminal appearance preview")
                Text("Applies immediately to all terminals. Some CLI apps use their own colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
