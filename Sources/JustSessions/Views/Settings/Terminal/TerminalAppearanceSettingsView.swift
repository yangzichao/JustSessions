import SwiftUI

/// The Terminal tab of Settings: colors, which match the app unless set here, and the font.
struct TerminalAppearanceSettingsView: View {
    @ObservedObject var appearanceStore: TerminalAppearanceStore
    /// For the preview, which shows the theme's terminal colors.
    let themeStore: AppThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
                GridRow {
                    Text("Colors")
                    Picker("Colors", selection: Binding(
                        get: { appearanceStore.preferences.mode },
                        set: { appearanceStore.setMode($0) }
                    )) {
                        ForEach(TerminalAppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Text("Font")
                    Picker("Font", selection: Binding(
                        get: { appearanceStore.preferences.fontFamily },
                        set: { appearanceStore.setFontFamily($0) }
                    )) {
                        ForEach(TerminalFontFamily.allCases) { family in
                            Text(family.displayName).tag(family)
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
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Preview").font(.subheadline.weight(.medium))
                TerminalAppearancePreview(appearanceStore: appearanceStore, themeStore: themeStore)
                    .frame(height: max(180, appearanceStore.preferences.fontSize * 9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ThemePalette.hairline))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Terminal appearance preview")
                Text("Applies immediately to all terminals. Some CLI apps use their own colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Restore Defaults") { appearanceStore.restoreDefaults() }
                    .disabled(appearanceStore.preferences == TerminalAppearancePreferences())
            }
        }
        .padding(24)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
    }
}
