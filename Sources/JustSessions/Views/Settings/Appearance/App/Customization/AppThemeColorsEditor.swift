import SwiftUI

/// Under the theme picker: the chosen theme's colors you can change, in its light or its dark version, which apply
/// to the whole app as you pick them. Collapsed until opened, unless the theme already has changes.
struct AppThemeColorsEditor: View {
    @ObservedObject var appThemeStore: AppThemeStore

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool
    /// Nil follows the window's appearance, so the version you see is the one you edit.
    @State private var editedVersionIsDark: Bool?
    /// The color whose last pick was refused, until a pick is taken or the version changes.
    @State private var refusedColor: CustomizableThemeColor?

    init(appThemeStore: AppThemeStore) {
        self.appThemeStore = appThemeStore
        _isExpanded = State(initialValue: !appThemeStore.resolvedTheme.customization.isEmpty)
    }

    private var editsDarkVersion: Bool {
        editedVersionIsDark ?? (colorScheme == .dark)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Picker("Version", selection: Binding(
                        get: { editsDarkVersion },
                        set: { isDark in
                            editedVersionIsDark = isDark
                            refusedColor = nil
                        }
                    )) {
                        Text("Light").tag(false)
                        Text("Dark").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Spacer(minLength: 0)
                    Button("Reset") {
                        appThemeStore.removeCustomization()
                        refusedColor = nil
                    }
                    .controlSize(.small)
                    .disabled(appThemeStore.resolvedTheme.customization.isEmpty)
                    .help("Gives the theme back its own colors, light and dark.")
                }
                colorRows
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Customize colors")
                HelpPopoverButton(
                    title: "Customize colors",
                    explanation: "Changes the chosen theme's colors, in its light or dark version. Your changes stay with the theme when you choose another one. Text is made readable on your colors, so the text color can come out darker or lighter than you chose. Terminals that match the app theme take its background."
                )
                .accessibilityIdentifier("settings.help.customizeThemeColors")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: appThemeStore.theme) { refusedColor = nil }
    }

    private var colorRows: some View {
        let isDark = editsDarkVersion
        let colors = appThemeStore.resolvedTheme.colors(isDark: isDark)
        let changes = appThemeStore.resolvedTheme.customization.changes(isDark: isDark)
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(CustomizableThemeColor.allCases) { color in
                ThemeColorWellRow(
                    color: color,
                    value: color.value(in: colors.seeds),
                    isChanged: changes[color] != nil,
                    isAdjustedForReadability: color == .ink && colors.ink != colors.seeds.ink,
                    refusal: refusedColor == color ? color.refusalMessage(isDark: isDark) : nil,
                    onChange: { value in
                        let isTaken = appThemeStore.setColor(value, for: color, isDark: isDark)
                        refusedColor = isTaken ? nil : color
                    }
                )
            }
        }
    }
}
